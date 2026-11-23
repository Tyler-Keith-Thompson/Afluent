//
//  DelaySequence.swift
//
//
//  Created by Tyler Thompson on 12/8/23.
//

import Foundation

extension AsyncSequences {
    /// Used as the implementation detail for the ``_Concurrency/AsyncSequence/delay(for:tolerance:jitter:)`` and ``_Concurrency/AsyncSequence/delay(for:tolerance:clock:jitter:)`` operator.
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    public struct Delay<Upstream: AsyncSequence & Sendable, C: Clock>: AsyncSequence, Sendable
    where Upstream.Element: Sendable {
        public typealias Element = Upstream.Element
        let upstream: Upstream
        let interval: C.Duration
        let clock: C
        let tolerance: C.Duration?
        let jitter: BackoffJitter

        public struct AsyncIterator: AsyncIteratorProtocol {
            typealias Instant = C.Instant
            let upstream: Upstream
            let interval: C.Duration
            var iterator: AsyncThrowingStream<(Instant, Element), Error>.Iterator
            let clock: C
            let tolerance: C.Duration?
            let jitter: BackoffJitter

            init(
                upstream: Upstream, interval: C.Duration, clock: C, tolerance: C.Duration?,
                jitter: BackoffJitter
            ) {
                self.upstream = upstream
                self.interval = interval
                self.clock = clock
                self.tolerance = tolerance
                self.jitter = jitter
                let stream = AsyncThrowingStream<(Instant, Element), Error> { continuation in
                    Task {
                        do {
                            for try await el in upstream {
                                continuation.yield((clock.now, el))
                            }
                            continuation.finish()
                        } catch {
                            continuation.finish(throwing: error)
                        }
                    }
                }
                iterator = stream.makeAsyncIterator()
            }

            public mutating func next() async throws -> Element? {
                try Task.checkCancellation()
                if let (instant, element) = try await iterator.next() {
                    let wait = jitter.jittered(interval, upTo: nil)
                    let suspensionPoint = instant.advanced(by: wait)
                    try await clock.sleep(until: suspensionPoint, tolerance: tolerance)
                    return element
                }
                return nil
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(
                upstream: upstream, interval: interval, clock: clock, tolerance: tolerance,
                jitter: jitter)
        }
    }
}

extension AsyncSequence where Self: Sendable, Element: Sendable {
    /// Delays delivery of all output by the specified amount of time, using a default clock.
    ///
    /// Use this to delay events from a sequence before they are delivered to the downstream consumer.
    ///
    /// - Parameters:
    ///   - interval: The duration to delay.
    ///   - tolerance: The allowed tolerance for the delay.
    ///   - jitter: How each element's delay is randomized. Defaults to ``BackoffJitter/none``.
    ///     Decorrelated jitter waits at most three times `interval`.
    /// - Returns: A sequence that delivers each element `interval` after the upstream produced it.
    ///
    /// The default clock is `SuspendingClock`.
    ///
    /// ## Example
    /// ```swift
    /// for try await value in Just(1).delay(for: .seconds(1), tolerance: .milliseconds(100)) {
    ///     print(value)
    /// }
    /// ```
    ///
    /// - Note: On WASI, a sleep on a real clock (`ContinuousClock`, `SuspendingClock`) holds the one thread
    ///   until its deadline, even when other work is ready, and cancelling it doesn't end it sooner. So each
    ///   delay waits out its whole duration, even when cancelled. A test clock is unaffected.
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    public func delay(
        for interval: Duration, tolerance: Duration, jitter: BackoffJitter = .none
    ) -> AsyncSequences.Delay<Self, SuspendingClock> {
        delay(for: interval, tolerance: tolerance, clock: SuspendingClock(), jitter: jitter)
    }

    /// Delays delivery of all output by the specified amount of time, using the provided clock.
    ///
    /// - Parameters:
    ///   - interval: The duration to delay.
    ///   - tolerance: The allowed tolerance for the delay. Default is `nil`.
    ///   - clock: The clock to use for timing the delay.
    ///   - jitter: How each element's delay is randomized. Defaults to ``BackoffJitter/none``.
    ///     Decorrelated jitter waits at most three times `interval`.
    /// - Returns: A sequence that delivers each element `interval` after the upstream produced it.
    ///
    /// ## Example
    /// ```swift
    /// for try await value in Just(1).delay(for: .seconds(1), clock: ContinuousClock()) {
    ///     print(value)
    /// }
    /// ```
    ///
    /// - Note: On WASI, a sleep on a real clock (`ContinuousClock`, `SuspendingClock`) holds the one thread
    ///   until its deadline, even when other work is ready, and cancelling it doesn't end it sooner. So each
    ///   delay waits out its whole duration, even when cancelled. A test clock is unaffected.
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    public func delay<C: Clock>(
        for interval: C.Duration, tolerance: C.Duration? = nil, clock: C,
        jitter: BackoffJitter = .none
    ) -> AsyncSequences.Delay<Self, C> {
        AsyncSequences.Delay(
            upstream: self, interval: interval, clock: clock, tolerance: tolerance, jitter: jitter)
    }
}
