//
//  TimerSequence.swift
//  Afluent
//
//  Created by Annalise Mariottini on 11/9/24.
//

import Foundation

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
extension AsyncSequences {
    /// A sequence that repeatedly emits an instant on a given interval.
    public struct TimerSequence<C: Clock>: AsyncSequence, Sendable {
        public typealias Element = C.Instant

        init(interval: C.Duration, tolerance: C.Duration?, clock: C) {
            self.interval = interval
            self.tolerance = tolerance
            self.clock = clock
        }

        private let interval: C.Duration
        private let tolerance: C.Duration?
        private let clock: C

        public struct AsyncIterator: AsyncIteratorProtocol {
            private var cancellables: Set<AnyCancellable> = []

            init(interval: C.Duration, tolerance: C.Duration?, clock: C) {
                let (stream, continuation) = AsyncStream<C.Instant>.makeStream()
                self.iterator = stream.makeAsyncIterator()

                DeferredTask {
                    while true {
                        try await clock.sleep(for: interval, tolerance: tolerance)
                        continuation.yield(clock.now)
                    }
                }.subscribe().store(in: &cancellables)
            }

            private var iterator: AsyncStream<Element>.Iterator

            public mutating func next() async -> Element? {
                await iterator.next()
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(interval: interval, tolerance: tolerance, clock: clock)
        }
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
public typealias TimerSequence = AsyncSequences.TimerSequence

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
extension TimerSequence where C == ContinuousClock {
    /// Returns a sequence that repeatedly emits an instant of a continuous clock on the given interval.
    ///
    /// - Parameters:
    ///   - interval: The time interval on which to publish events. For example, a value of `.milliseconds(1)` will publish an event approximately every 0.01 seconds.
    ///   - tolerance: The allowed timing variance when emitting events. Defaults to `nil`, which will schedule with the default tolerance strategy.
    public static func publish(every interval: C.Duration, tolerance: C.Duration? = nil)
        -> AsyncSequences.TimerSequence<C>
    {
        AsyncSequences.TimerSequence(interval: interval, tolerance: tolerance, clock: .init())
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
extension TimerSequence {
    /// Returns a sequence that repeatedly emits an instant of the passed clock on the given interval.
    ///
    /// - Parameters:
    ///   - interval: The time interval on which to publish events. For example, a value of `.milliseconds(1)` will publish an event approximately every 0.01 seconds.
    ///   - tolerance: The allowed timing variance when emitting events. Defaults to `nil`, which will schedule with the default tolerance strategy.
    ///   - clock: The clock instance to utilize for sequence timing. For example, `ContinuousClock` or `SuspendingClock`.
    public static func publish(every interval: C.Duration, tolerance: C.Duration? = nil, clock: C)
        -> AsyncSequences.TimerSequence<C>
    {
        AsyncSequences.TimerSequence(interval: interval, tolerance: tolerance, clock: clock)
    }
}
