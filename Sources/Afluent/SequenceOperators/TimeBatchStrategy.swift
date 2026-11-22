//
//  TimeBatchStrategy.swift
//  Afluent
//

import Foundation

/// A ``BatchStrategy`` that flushes each time an interval passes on a clock.
///
/// The timer starts when iteration begins and starts over after every flush, including flushes
/// another strategy in ``EitherBatchStrategy`` caused, so a batch is never older than the
/// interval. When the interval passes with nothing pending, nothing is emitted and the timer
/// starts over.
///
/// ## Example
/// ```swift
/// for try await second in sensor.readings.batch(
///     strategy: .time(interval: .seconds(1), clock: ContinuousClock())) {
///     print(second) // The readings of each second that had any
/// }
/// ```
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
public struct TimeBatchStrategy<Element, C: Clock>: BatchStrategy {
    /// How long elements gather before they are flushed.
    public let interval: C.Duration
    /// The clock that measures the interval.
    public let clock: C
    /// The tolerance of the timer's sleeps.
    public let tolerance: C.Duration?

    /// Creates a strategy that flushes every `interval` on `clock`.
    ///
    /// - Parameters:
    ///   - interval: How long elements gather before they are flushed.
    ///   - clock: The clock that measures the interval.
    ///   - tolerance: The tolerance of the timer's sleeps. Defaults to `nil`.
    /// - Precondition: `interval` is greater than zero.
    public init(interval: C.Duration, clock: C, tolerance: C.Duration? = nil) {
        precondition(interval > .zero, "A batch's interval must be greater than zero")
        self.interval = interval
        self.clock = clock
        self.tolerance = tolerance
    }

    public func run(_ flusher: BatchFlusher) async throws {
        let clock = clock
        let timer = CriticalState(TimerState(start: clock.now, epoch: 0))
        // Also called once now, under the batch's lock: the interval starts there, so a flush
        // that lands before this registration still moves the first deadline.
        flusher.onFlush {
            timer.withCriticalRegion { timer in
                timer.start = clock.now
                timer.epoch &+= 1
            }
        }
        while true {
            let (deadline, epoch) = timer.withCriticalRegion {
                ($0.start.advanced(by: interval), $0.epoch)
            }
            try await clock.sleep(until: deadline, tolerance: tolerance)
            // A flush while this sleep ran moved the deadline; it fires only if none did.
            flusher.flush { timer.withCriticalRegion { $0.epoch == epoch } }
        }
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
extension TimeBatchStrategy {
    /// When the current interval began, and how many flushes have started it over.
    fileprivate struct TimerState: Sendable {
        var start: C.Instant
        var epoch: Int
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
extension BatchStrategy {
    /// Flushes each time the interval passes on the given clock.
    ///
    /// ## Example
    /// ```swift
    /// let readings = sensor.readings.batch(
    ///     strategy: .time(interval: .seconds(1), clock: ContinuousClock()))
    /// for try await second in readings {
    ///     print(second) // The readings of each second that had any
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - interval: How long elements gather before they are flushed.
    ///   - clock: The clock that measures the interval.
    ///   - tolerance: The tolerance of the timer's sleeps. Defaults to `nil`.
    /// - Returns: A ``TimeBatchStrategy``.
    /// - Precondition: `interval` is greater than zero.
    public static func time<Batched, C: Clock>(
        interval: C.Duration, clock: C, tolerance: C.Duration? = nil
    ) -> TimeBatchStrategy<Batched, C> where Self == TimeBatchStrategy<Batched, C> {
        TimeBatchStrategy(interval: interval, clock: clock, tolerance: tolerance)
    }
}
