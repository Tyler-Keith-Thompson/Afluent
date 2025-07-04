//
//  TimerSequence.swift
//  Afluent
//
//  Created by Annalise Mariottini on 11/9/24.
//

import Foundation

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
extension AsyncSequences {
    /// A timer-based asynchronous sequence that emits the current instant of a specified clock
    /// at a regular interval.
    ///
    /// This sequence repeatedly waits for the specified time interval, then emits a timestamp
    /// representing the current instant according to the clock.
    ///
    /// This can be used to perform periodic asynchronous tasks or to observe regular time ticks.
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
                self.interval = interval
                self.tolerance = tolerance
                self.clock = clock
            }

            private let interval: C.Duration
            private let tolerance: C.Duration?
            private let clock: C
            private var last: C.Instant?
            private var finished = false

            public mutating func next() async -> C.Instant? {
                guard !finished else {
                    return nil
                }
                let next = (self.last ?? clock.now).advanced(by: self.interval)
                do {
                    try await clock.sleep(until: next, tolerance: self.tolerance)
                } catch {
                    self.finished = true
                    return nil
                }
                let now = clock.now
                self.last = next
                return now
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
    /// Creates a timer sequence that emits the current instant of a continuous clock at the specified interval.
    ///
    /// - Parameters:
    ///   - interval: The time interval between emitted instants.
    ///   - tolerance: An optional tolerance for scheduling, allowing slight variance in timing.
    ///
    /// ## Example
    /// ```swift
    /// let timer = TimerSequence<ContinuousClock>.publish(every: .seconds(1))
    /// for await instant in timer {
    ///     print("Tick at \(instant)")
    /// }
    /// // Prints a line every second with the current instant.
    /// ```
    public static func publish(every interval: C.Duration, tolerance: C.Duration? = nil)
        -> AsyncSequences.TimerSequence<C>
    {
        AsyncSequences.TimerSequence(interval: interval, tolerance: tolerance, clock: .init())
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
extension TimerSequence {
    /// Creates a timer sequence that emits the current instant of the specified clock at the given interval.
    ///
    /// - Parameters:
    ///   - interval: The time interval between emitted instants.
    ///   - tolerance: An optional tolerance for scheduling, allowing slight variance in timing.
    ///   - clock: The clock instance to use for timing.
    ///
    /// ## Example
    /// ```swift
    /// let customClock = ContinuousClock()
    /// let timer = TimerSequence.publish(every: .seconds(1), tolerance: nil, clock: customClock)
    /// for await instant in timer {
    ///     print("Tick at \(instant)")
    /// }
    /// // Prints a line every second with the current instant.
    /// ```
    public static func publish(every interval: C.Duration, tolerance: C.Duration? = nil, clock: C)
        -> AsyncSequences.TimerSequence<C>
    {
        AsyncSequences.TimerSequence(interval: interval, tolerance: tolerance, clock: clock)
    }
}
