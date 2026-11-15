//
//  TimeoutSequence.swift
//  Afluent
//

import Foundation

extension AsyncSequences {
    /// Used as the implementation detail for the ``_Concurrency/AsyncSequence/timeout(_:clock:tolerance:customError:)`` operator.
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    public struct Timeout<Upstream: AsyncSequence & Sendable, C: Clock>: AsyncSequence, Sendable
    where Upstream.Element: Sendable {
        public typealias Element = Upstream.Element
        let upstream: Upstream
        let duration: C.Duration
        let clock: C
        let tolerance: C.Duration?
        let customError: (any Error)?

        public struct AsyncIterator: AsyncIteratorProtocol {
            let upstream: Upstream
            let duration: C.Duration
            let clock: C
            let tolerance: C.Duration?
            let customError: (any Error)?
            var iterator: AsyncThrowingStream<Element, any Error>.Iterator?

            public mutating func next() async throws -> Element? {
                try Task.checkCancellation()
                if iterator == nil {
                    iterator = start().makeAsyncIterator()
                }
                return try await iterator?.next()
            }

            /// Starts pulling the upstream and the idle timer. The timer's deadline moves forward
            /// with every element; whichever of the two ends first finishes the stream.
            private func start() -> AsyncThrowingStream<Element, any Error> {
                let (stream, continuation) = AsyncThrowingStream<Element, any Error>.makeStream()
                let upstream = upstream
                let duration = duration
                let clock = clock
                let tolerance = tolerance
                let timeoutError = customError ?? TimeoutError.timedOut(duration: duration)
                guard duration > .zero else {
                    continuation.finish(throwing: timeoutError)
                    return stream
                }
                let state = CriticalState(
                    IdleState(deadline: clock.now.advanced(by: duration), finished: false))

                let task = Task {
                    await withTaskGroup(of: Void.self) { group in
                        group.addTask {
                            do {
                                for try await element in upstream {
                                    let delivered = state.withCriticalRegion { state in
                                        guard !state.finished else { return false }
                                        state.deadline = clock.now.advanced(by: duration)
                                        continuation.yield(element)
                                        return true
                                    }
                                    guard delivered else { return }
                                }
                                Self.finish(state) { continuation.finish() }
                            } catch {
                                Self.finish(state) { continuation.finish(throwing: error) }
                            }
                        }
                        group.addTask {
                            while true {
                                let deadline = state.withCriticalRegion { $0.deadline }
                                do {
                                    try await clock.sleep(until: deadline, tolerance: tolerance)
                                } catch {
                                    return
                                }
                                // Unchanged since the sleep began: no element arrived in time.
                                let expired = state.withCriticalRegion { $0.deadline == deadline }
                                if expired {
                                    Self.finish(state) { continuation.finish(throwing: timeoutError) }
                                    return
                                }
                            }
                        }
                        await group.next()
                        group.cancelAll()
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
                return stream
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(
                upstream: upstream, duration: duration, clock: clock, tolerance: tolerance,
                customError: customError)
        }
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
extension AsyncSequences.Timeout.AsyncIterator {
    /// When the timer fires unless another element arrives, and whether the stream has ended.
    struct IdleState: Sendable {
        var deadline: C.Instant
        var finished: Bool
    }

    /// Runs `body` once, for whichever side ends the stream first.
    static func finish(_ state: CriticalState<IdleState>, _ body: () -> Void) {
        state.withCriticalRegion { state in
            guard !state.finished else { return }
            state.finished = true
            body()
        }
    }
}

extension AsyncSequence where Self: Sendable, Element: Sendable {
    /// Fails if the sequence goes the given duration without producing an element, measured on
    /// a `SuspendingClock`.
    ///
    /// The timer starts when iteration begins and restarts with every element, so it bounds the
    /// wait for the first element and each gap after it, never the sequence as a whole. Elements
    /// pass through unchanged. When the timer fires, the upstream is cancelled and the sequence
    /// throws.
    ///
    /// The upstream is read ahead of the consumer, and elements it produces while the consumer is
    /// busy are buffered, so the timer measures the upstream's gaps. A duration of zero or less
    /// throws before the first element.
    ///
    /// ## Example
    /// ```swift
    /// for try await event in serverEvents.timeout(.seconds(30)) {
    ///     handle(event)
    /// }
    /// // Throws TimeoutError.timedOut if 30 seconds pass without an event
    /// ```
    ///
    /// - Parameters:
    ///   - duration: The longest the sequence may go without an element.
    ///   - customError: The error to throw when the timer fires. Defaults to
    ///     `TimeoutError.timedOut(duration:)`.
    /// - Returns: A sequence of the same elements that throws if the upstream goes quiet.
    /// - Throws: `TimeoutError` (or `customError`) when `duration` passes between elements, and
    ///   any error the upstream throws.
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    public func timeout(_ duration: Duration, customError: (any Error)? = nil)
        -> AsyncSequences.Timeout<Self, SuspendingClock>
    {
        timeout(duration, clock: SuspendingClock(), customError: customError)
    }

    /// Fails if the sequence goes the given duration without producing an element, measured on
    /// the given clock.
    ///
    /// The timer starts when iteration begins and restarts with every element, so it bounds the
    /// wait for the first element and each gap after it, never the sequence as a whole. Elements
    /// pass through unchanged. When the timer fires, the upstream is cancelled and the sequence
    /// throws, without waiting for the upstream to respond to the cancellation.
    ///
    /// The upstream is read ahead of the consumer, and elements it produces while the consumer is
    /// busy are buffered, so the timer measures the upstream's gaps. A duration of zero or less
    /// throws before the first element.
    ///
    /// ## Example
    /// ```swift
    /// let clock = ContinuousClock()
    /// for try await line in bytes.lines.timeout(.seconds(30), clock: clock) {
    ///     handle(line)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - duration: The longest the sequence may go without an element.
    ///   - clock: The clock that measures the gaps.
    ///   - tolerance: The tolerance of the timer's sleeps. Defaults to `nil`.
    ///   - customError: The error to throw when the timer fires. Defaults to
    ///     `TimeoutError.timedOut(duration:)`.
    /// - Returns: A sequence of the same elements that throws if the upstream goes quiet.
    /// - Throws: `TimeoutError` (or `customError`) when `duration` passes between elements, and
    ///   any error the upstream throws.
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    public func timeout<C: Clock>(
        _ duration: C.Duration, clock: C, tolerance: C.Duration? = nil,
        customError: (any Error)? = nil
    ) -> AsyncSequences.Timeout<Self, C> {
        AsyncSequences.Timeout(
            upstream: self, duration: duration, clock: clock, tolerance: tolerance,
            customError: customError)
    }
}
