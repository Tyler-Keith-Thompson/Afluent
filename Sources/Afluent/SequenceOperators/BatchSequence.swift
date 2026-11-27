//
//  BatchSequence.swift
//  Afluent
//

import Foundation

extension AsyncSequences {
    /// Used as the implementation detail for the ``_Concurrency/AsyncSequence/batch(strategy:)`` operator.
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    public struct Batch<Upstream: AsyncSequence & Sendable, Strategy: BatchStrategy>: AsyncSequence,
        Sendable
    where Upstream.Element: Sendable, Strategy.Element == Upstream.Element {
        public typealias Element = [Upstream.Element]
        let upstream: Upstream
        let strategy: Strategy

        public struct AsyncIterator: AsyncIteratorProtocol {
            let upstream: Upstream
            let strategy: Strategy
            var iterator: AsyncThrowingStream<Element, any Error>.Iterator?
            var continuation: AsyncThrowingStream<Element, any Error>.Continuation?

            public mutating func next() async throws -> Element? {
                guard !Task.isCancelled else {
                    // Ends the stream, which cancels the upstream and the strategy.
                    continuation?.finish()
                    throw CancellationError()
                }
                if iterator == nil {
                    // Before anything starts, so an out-of-range argument is the first thing the
                    // caller hears and no element is read or emitted.
                    try (strategy as? any ValidatedBatchStrategy)?.validate()
                    let (stream, continuation) = start()
                    iterator = stream.makeAsyncIterator()
                    self.continuation = continuation
                }
                return try await iterator?.next()
            }

            /// Starts pulling the upstream and running the strategy, each in a child task. Every
            /// flush happens under one lock, which also orders it against the elements that
            /// arrive.
            private func start() -> (
                AsyncThrowingStream<Element, any Error>,
                AsyncThrowingStream<Element, any Error>.Continuation
            ) {
                let (stream, continuation) = AsyncThrowingStream<Element, any Error>.makeStream()
                let upstream = upstream
                let strategy = strategy
                let batch = PendingBatch(
                    state: CriticalState(
                        PendingBatch.State(elements: [], finished: false, flushObservers: [])),
                    strategy: strategy,
                    continuation: continuation)

                let task = Task {
                    await withTaskGroup(of: Bool.self) { group in
                        // Each child returns whether it ended the stream. A strategy whose
                        // `run(_:)` returns has no more to do, and the batches go on.
                        group.addTask {
                            await batch.drain(upstream)
                            return true
                        }
                        group.addTask {
                            do {
                                try await strategy.run(batch.flusher)
                                return false
                            } catch {
                                guard !Task.isCancelled else { return false }
                                batch.fail(error)
                                return true
                            }
                        }
                        for await ended in group where ended {
                            group.cancelAll()
                            return
                        }
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
                return (stream, continuation)
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(upstream: upstream, strategy: strategy)
        }
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
extension AsyncSequences.Batch.AsyncIterator {
    /// The elements gathered since the last flush, and how they leave: shared by the upstream's
    /// task and the strategy's.
    struct PendingBatch: Sendable {
        struct State: Sendable {
            var elements: [Upstream.Element]
            var finished: Bool
            var flushObservers: [@Sendable () -> Void]
        }

        // A lock rather than an actor: every element and every flush takes it, and none of them
        // suspends while holding it.
        let state: CriticalState<State>
        let strategy: Strategy
        let continuation: AsyncThrowingStream<[Upstream.Element], any Error>.Continuation

        /// The handle the strategy flushes through.
        var flusher: BatchFlusher {
            let batch = self
            return BatchFlusher(
                flushIfDue: { isDue in batch.flush(if: isDue) },
                observeFlushes: { observer in
                    // Called once here, under the same lock as every flush, so a strategy that
                    // sets its starting point in the observer can't miss a flush.
                    batch.state.withCriticalRegion { state in
                        state.flushObservers.append(observer)
                        observer()
                    }
                })
        }

        /// Reads the upstream to its end, asking the strategy after each element whether to
        /// flush, then flushes what is left and finishes. An error drops the pending elements
        /// and ends the stream with it.
        func drain(_ upstream: Upstream) async {
            do {
                for try await element in upstream {
                    // An upstream that ignores cancellation keeps returning elements; none of
                    // them can reach a consumer any more, so stop reading.
                    guard !Task.isCancelled else { return }
                    let accepted = state.withCriticalRegion { state in
                        guard !state.finished else { return false }
                        state.elements.append(element)
                        if strategy.flushes(pending: state.elements) {
                            flush(&state)
                        }
                        return true
                    }
                    guard accepted else { return }
                }
                state.withCriticalRegion { state in
                    guard !state.finished else { return }
                    state.finished = true
                    if !state.elements.isEmpty {
                        continuation.yield(state.elements)
                        state.elements = []
                    }
                    continuation.finish()
                }
            } catch {
                fail(error)
            }
        }

        /// Flushes if the stream is still open and `isDue` holds under the lock.
        func flush(if isDue: () -> Bool) {
            state.withCriticalRegion { state in
                guard !state.finished, isDue() else { return }
                flush(&state)
            }
        }

        /// Ends the stream with `error`, dropping the pending elements, unless it already ended.
        func fail(_ error: any Error) {
            state.withCriticalRegion { state in
                guard !state.finished else { return }
                state.finished = true
                state.elements = []
                continuation.finish(throwing: error)
            }
        }

        /// Emits the pending elements, if there are any, and tells every flush observer, so
        /// strategies start over.
        private func flush(_ state: inout State) {
            if !state.elements.isEmpty {
                continuation.yield(state.elements)
                state.elements = []
            }
            for observer in state.flushObservers { observer() }
        }
    }
}

extension AsyncSequence where Self: Sendable, Element: Sendable {
    /// Gathers elements into arrays and emits each array when the strategy says to flush.
    ///
    /// The strategy decides when the pending elements are flushed: every so many elements
    /// (``BatchStrategy/count(_:)``), every interval
    /// (``BatchStrategy/time(interval:clock:tolerance:)``), on a signal or a unit of work
    /// (``SignalBatchStrategy``), whenever any of several does
    /// (``BatchStrategy/either(_:_:)``), or by a rule of your own (``BatchStrategy``). After every
    /// flush, each strategy starts over. A flush with nothing pending emits nothing; the
    /// sequence never emits an empty array.
    ///
    /// When the upstream finishes, the pending elements, if any, are emitted as a last array and
    /// the sequence finishes. When the upstream throws, the pending elements are dropped and the
    /// sequence throws the same error. A signal that finishes stops firing while the batches go
    /// on; a signal that throws ends the sequence with its error.
    ///
    /// The upstream and the strategy run in tasks of their own, started when iteration begins,
    /// so the upstream is read ahead of the consumer, and arrays the consumer hasn't taken yet
    /// are buffered. Cancelling the consumer, or dropping its iterator, cancels both. An
    /// upstream or signal that ignores cancellation keeps the internal task alive until its
    /// pending `next()` returns, and is not read again after that; the batched sequence itself
    /// ends at once.
    ///
    /// Batching needs iOS 16, Mac Catalyst 16, macOS 13, tvOS 16, watchOS 9 or visionOS 1.
    ///
    /// ## Example
    /// ```swift
    /// for try await batch in [1, 2, 3, 4].async.batch(strategy: .either(.count(3), .time(interval: .seconds(1), clock: ContinuousClock()))) {
    ///     print(batch) // Prints [1, 2, 3], then [4]
    /// }
    /// ```
    ///
    /// - Parameter strategy: When to emit the gathered elements; its `Element` is this
    ///   sequence's, inferred from the call.
    /// - Returns: A sequence of the upstream's elements, in order, in arrays of one or more.
    /// - Throws: Any error the upstream or the strategy throws.
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    public func batch<Strategy: BatchStrategy>(strategy: Strategy)
        -> AsyncSequences.Batch<Self, Strategy>
    where Strategy.Element == Element {
        AsyncSequences.Batch(upstream: self, strategy: strategy)
    }
}
