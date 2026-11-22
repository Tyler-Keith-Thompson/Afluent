//
//  BatchSequence.swift
//  Afluent
//

import Foundation

extension AsyncSequences {
    /// Used as the implementation detail for the ``_Concurrency/AsyncSequence/batch(strategy:)`` operator.
    public struct Batch<Upstream: AsyncSequence & Sendable>: AsyncSequence, Sendable
    where Upstream.Element: Sendable {
        public typealias Element = [Upstream.Element]
        let upstream: Upstream
        let strategy: BatchStrategy

        public struct AsyncIterator: AsyncIteratorProtocol {
            let upstream: Upstream
            let strategy: BatchStrategy
            var iterator: AsyncThrowingStream<Element, any Error>.Iterator?
            var continuation: AsyncThrowingStream<Element, any Error>.Continuation?

            public mutating func next() async throws -> Element? {
                guard !Task.isCancelled else {
                    // Ends the stream, which cancels the upstream, the timers and the signals.
                    continuation?.finish()
                    throw CancellationError()
                }
                if iterator == nil {
                    let (stream, continuation) = start()
                    iterator = stream.makeAsyncIterator()
                    self.continuation = continuation
                }
                return try await iterator?.next()
            }

            /// Starts pulling the upstream and arms the strategy's timers and signals, each in a
            /// child task, so whichever fires first flushes. Every flush happens under one lock,
            /// which also orders it against the elements that arrive.
            private func start() -> (
                AsyncThrowingStream<Element, any Error>,
                AsyncThrowingStream<Element, any Error>.Continuation
            ) {
                let (stream, continuation) = AsyncThrowingStream<Element, any Error>.makeStream()
                let upstream = upstream
                let triggers = strategy.triggers.map { $0.arm() }
                let batch = PendingBatch(
                    state: CriticalState(PendingBatch.State(elements: [], finished: false)),
                    count: strategy.count,
                    resets: triggers.map(\.reset),
                    continuation: continuation)

                let task = Task {
                    // Each child returns whether it ended the stream. A signal that finishes
                    // returns false, and the batches go on.
                    await withTaskGroup(of: Bool.self) { group in
                        group.addTask {
                            await batch.drain(upstream)
                            return true
                        }
                        for trigger in triggers {
                            group.addTask {
                                do {
                                    try await trigger.run { isDue in batch.flush(if: isDue) }
                                    return false
                                } catch {
                                    guard !Task.isCancelled else { return false }
                                    batch.fail(error)
                                    return true
                                }
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

extension AsyncSequences.Batch.AsyncIterator {
    /// The elements gathered since the last flush, and how they leave: shared by the upstream's
    /// task and every trigger's.
    struct PendingBatch: Sendable {
        struct State: Sendable {
            var elements: [Upstream.Element]
            var finished: Bool
        }

        // A lock rather than an actor: every element and every firing takes it, and none of them
        // suspends while holding it.
        let state: CriticalState<State>
        let count: Int?
        let resets: [@Sendable () -> Void]
        let continuation: AsyncThrowingStream<[Upstream.Element], any Error>.Continuation

        /// Reads the upstream to its end, flushing on the count, then flushes what is left and
        /// finishes. An error drops the pending elements and ends the stream with it.
        func drain(_ upstream: Upstream) async {
            do {
                for try await element in upstream {
                    let accepted = state.withCriticalRegion { state in
                        guard !state.finished else { return false }
                        state.elements.append(element)
                        if let count, state.elements.count >= count {
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

        /// Emits the pending elements, if there are any, and starts every trigger over.
        private func flush(_ state: inout State) {
            if !state.elements.isEmpty {
                continuation.yield(state.elements)
                state.elements = []
            }
            for reset in resets { reset() }
        }
    }
}

extension AsyncSequence where Self: Sendable, Element: Sendable {
    /// Gathers elements into arrays and emits each array when the strategy fires.
    ///
    /// The strategy decides when the pending elements are flushed: every so many elements
    /// (``BatchStrategy/count(_:)``), every interval (``BatchStrategy/time(interval:clock:tolerance:)``),
    /// on a signal (``BatchStrategy/signal(_:)-(Signal)``), or whenever any of several fires
    /// (``BatchStrategy/either(_:)``). After every flush, each strategy starts over. A timer or
    /// signal that fires with nothing pending emits nothing; the sequence never emits an empty
    /// array.
    ///
    /// When the upstream finishes, the pending elements, if any, are emitted as a last array and
    /// the sequence finishes. When the upstream throws, the pending elements are dropped and the
    /// sequence throws the same error. A signal that finishes stops firing while the batches go
    /// on; a signal that throws ends the sequence with its error.
    ///
    /// The upstream, the timers and the signals run in tasks of their own, started when
    /// iteration begins, so the upstream is read ahead of the consumer, and arrays the consumer
    /// hasn't taken yet are buffered. Cancelling the consumer, or dropping its iterator, cancels
    /// all of them. An upstream or signal that ignores cancellation keeps the internal task alive
    /// until it returns, though the batched sequence itself ends at once.
    ///
    /// ## Example
    /// ```swift
    /// let strategy = BatchStrategy.either(
    ///     .count(3),
    ///     .time(interval: .seconds(1), clock: ContinuousClock()))
    /// for try await batch in [1, 2, 3, 4].async.batch(strategy: strategy) {
    ///     print(batch) // Prints [1, 2, 3], then [4]
    /// }
    /// ```
    ///
    /// - Parameter strategy: When to emit the gathered elements.
    /// - Returns: A sequence of the upstream's elements, in order, in arrays of one or more.
    /// - Throws: Any error the upstream or a signal throws.
    public func batch(strategy: BatchStrategy) -> AsyncSequences.Batch<Self> {
        AsyncSequences.Batch(upstream: self, strategy: strategy)
    }
}
