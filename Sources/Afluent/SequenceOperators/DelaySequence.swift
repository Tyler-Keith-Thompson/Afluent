//
//  DelaySequence.swift
//
//
//  Created by Tyler Thompson on 12/8/23.
//

import Foundation

extension AsyncSequences {
    /// Used as the implementation detail for the ``AsyncSequence/delay(for:tolerance:)`` operator.
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    public struct Delay<Upstream: AsyncSequence & Sendable, C: Clock>: AsyncSequence, Sendable
    where Upstream.Element: Sendable {
        public typealias Element = Upstream.Element
        let upstream: Upstream
        let interval: C.Duration
        let clock: C
        let tolerance: C.Duration?

        public struct AsyncIterator: AsyncIteratorProtocol {
            typealias Instant = C.Instant
            let upstream: Upstream
            let interval: C.Duration
            var iterator: AsyncThrowingStream<(Instant, Element), Error>.Iterator
            let clock: C
            let tolerance: C.Duration?

            init(upstream: Upstream, interval: C.Duration, clock: C, tolerance: C.Duration?) {
                self.upstream = upstream
                self.interval = interval
                self.clock = clock
                self.tolerance = tolerance
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
                    let suspensionPoint = instant.advanced(by: interval)
                    try await clock.sleep(until: suspensionPoint, tolerance: tolerance)
                    return element
                }
                return nil
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(
                upstream: upstream, interval: interval, clock: clock, tolerance: tolerance)
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
    ///
    /// The default clock is `SuspendingClock`.
    ///
    /// ## Example
    /// ```
    /// for try await value in Just(1).delay(for: .seconds(1), tolerance: .milliseconds(100)) {
    ///     print(value)
    /// }
    /// ```
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    public func delay(for interval: Duration, tolerance: Duration)
        -> AsyncSequences.Delay<Self, SuspendingClock>
    {
        delay(for: interval, tolerance: tolerance, clock: SuspendingClock())
    }

    /// Delays delivery of all output by the specified amount of time, using the provided clock.
    ///
    /// - Parameters:
    ///   - interval: The duration to delay.
    ///   - tolerance: The allowed tolerance for the delay. Default is `nil`.
    ///   - clock: The clock to use for timing the delay.
    ///
    /// ## Example
    /// ```
    /// for try await value in Just(1).delay(for: .seconds(1), clock: ContinuousClock()) {
    ///     print(value)
    /// }
    /// ```
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    public func delay<C: Clock>(for interval: C.Duration, tolerance: C.Duration? = nil, clock: C)
        -> AsyncSequences.Delay<Self, C>
    {
        AsyncSequences.Delay(upstream: self, interval: interval, clock: clock, tolerance: tolerance)
    }
}
