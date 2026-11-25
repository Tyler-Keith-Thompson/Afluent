//
//  RetryByBackoffStrategy.swift
//  Afluent
//
//  Created by Tyler Thompson on 9/19/24.
//

import Foundation

/// A closure that converts an integer value to a duration for a given clock.
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public typealias ClockDurationUnit<C: Clock, T: BinaryInteger> = @Sendable (T) -> C.Duration

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension RetryStrategy
where Self == RetryByBackoffStrategy<ExponentialBackoffStrategy<ContinuousClock>> {
    /// Creates a retry strategy using the provided exponential backoff and a continuous clock.
    ///
    /// This convenience function can be used with operators such as `.retry(strategy:)`.
    ///
    /// ## Example
    /// ```swift
    /// try await DeferredTask { /* some fallible work */ }
    ///     .retry(strategy: .backoff(.exponential(base: 2, maxCount: 3)))
    ///     .execute()
    /// ```
    public static func backoff(_ strategy: ExponentialBackoffStrategy<ContinuousClock>)
        -> RetryByBackoffStrategy<ExponentialBackoffStrategy<ContinuousClock>>
    {
        RetryByBackoffStrategy(strategy, clock: ContinuousClock(), durationUnit: Duration.seconds)
    }
}

/// A retry strategy using a specified backoff strategy and clock.
///
/// This actor manages retry attempts with a configurable `BackoffStrategy` and clock. It determines delays between retries using this strategy.
///
/// ## Example
/// ```swift
/// try await DeferredTask { /* some fallible work */ }
///     .retry(strategy: .backoff(.exponential(base: 2, maxCount: 3)))
///     .execute()
/// ```
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public actor RetryByBackoffStrategy<Strategy: BackoffStrategy>: RetryStrategy {
    let strategy: Strategy
    let clock: Strategy.Clock
    let durationUnit: ClockDurationUnit<Strategy.Clock, Int>

    /// Creates a new retry strategy with the given backoff strategy and clock.
    ///
    /// - Parameters:
    ///   - strategy: The backoff strategy used to determine how to back off between retries.
    ///   - clock: The clock used to measure the time between retries.
    ///   - durationUnit: A closure that converts an integer to a clock duration.
    public init(
        _ strategy: Strategy, clock: Strategy.Clock,
        durationUnit: @escaping ClockDurationUnit<Strategy.Clock, Int>
    ) {
        self.strategy = strategy
        self.clock = clock
        self.durationUnit = durationUnit
    }

    /// Creates a new retry strategy with the given backoff strategy and clock, counting in seconds.
    ///
    /// The duration unit passed to the backoff strategy is `Duration.seconds`, so
    /// `ExponentialBackoffStrategy(base: 2)` waits 2, 4, 8, … seconds. A strategy made with
    /// ``ExponentialBackoffStrategy/init(initialDelay:multiplier:maxCount:maxDelay:jitter:)``
    /// states its delays as durations and ignores the unit.
    ///
    /// ## Example
    /// ```swift
    /// let strategy = ExponentialBackoffStrategy<ContinuousClock>(
    ///     initialDelay: .seconds(1), multiplier: 2, maxDelay: .seconds(60))
    /// try await DeferredTask { /* some fallible work */ }
    ///     .retry(RetryByBackoffStrategy(strategy, clock: ContinuousClock()))
    ///     .execute()
    /// ```
    ///
    /// - Parameters:
    ///   - strategy: The backoff strategy used to determine how to back off between retries.
    ///   - clock: The clock used to measure the time between retries.
    public init(_ strategy: Strategy, clock: Strategy.Clock)
    where Strategy.Clock.Duration == Duration {
        self.init(strategy, clock: clock, durationUnit: Duration.seconds)
    }

    /// Waits out the backoff strategy's next delay and reports whether to retry.
    ///
    /// - Parameters:
    ///   - err: The error that occurred during the operation.
    ///   - beforeRetry: A closure for work before a retry; this strategy doesn't call it.
    /// - Returns: The backoff strategy's answer: `true` to retry, `false` to stop.
    /// - Throws: Any error the backoff strategy throws.
    public func handle(error err: Error, beforeRetry: @Sendable (Error) async throws -> Void)
        async throws -> Bool
    {
        try await strategy.backoff(clock: clock, durationUnit: durationUnit)
    }
}

/// A protocol for implementing custom backoff strategies for retry mechanisms.
///
/// Conforming types provide logic to determine the delay between retry attempts using a clock and a duration unit.
///
/// ## Example
/// ```swift
/// struct MyStrategy: BackoffStrategy {
///     func backoff<T: BinaryInteger>(clock: ContinuousClock, durationUnit: @escaping ClockDurationUnit<ContinuousClock, T>) async throws -> Bool {
///         try await clock.sleep(for: durationUnit(1))
///         return true
///     }
/// }
/// ```
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public protocol BackoffStrategy<Clock>: Sendable where Clock: _Concurrency.Clock {
    associatedtype Clock
    /// Calculates the delay between retries using a clock and a duration unit.
    ///
    /// - Parameters:
    ///   - clock: The clock used to measure the time between retries.
    ///   - durationUnit: A closure that converts an integer value to a clock duration.
    ///
    /// - Returns: A Boolean indicating whether a retry should be attempted (`true`) or not (`false`).
    /// - Throws: Any error encountered during the backoff process.
    func backoff<T: BinaryInteger>(clock: Clock, durationUnit: ClockDurationUnit<Clock, T>)
        async throws -> Bool
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension BackoffStrategy where Self == ExponentialBackoffStrategy<ContinuousClock> {
    /// Creates an exponential backoff strategy with a configurable base and maximum retry count.
    ///
    /// - Parameters:
    ///   - base: The base duration for the backoff, which will exponentially increase with each retry.
    ///   - maxCount: The maximum number of attempts. Defaults to `UInt.max`, which never stops.
    ///   - maxDelay: The maximum duration to wait.
    ///   - jitter: How each delay is randomized. Defaults to ``BackoffJitter/none``.
    /// - Returns: An `ExponentialBackoffStrategy` configured with the provided base and maximum retry count.
    public static func exponential(
        base: UInt, maxCount: UInt = .max,
        maxDelay: ContinuousClock.Duration = .seconds(Int.max), jitter: BackoffJitter = .none
    ) -> ExponentialBackoffStrategy<Clock> {
        ExponentialBackoffStrategy(base: base, maxCount: maxCount, maxDelay: maxDelay, jitter: jitter)
    }

    /// Creates an exponential backoff strategy that waits an initial delay, then multiplies it after
    /// each retry, up to a maximum delay.
    ///
    /// The waits are `initialDelay`, `initialDelay × multiplier`, `initialDelay × multiplier²`, …,
    /// each capped at `maxDelay`.
    ///
    /// ## Example
    /// ```swift
    /// // Waits 1, 2, 4, 8, 16, 32, then 60 seconds between attempts, for ever.
    /// try await DeferredTask { /* some fallible work */ }
    ///     .retry(.backoff(.exponential(initialDelay: .seconds(1), multiplier: 2, maxDelay: .seconds(60))))
    ///     .execute()
    /// ```
    ///
    /// - Parameters:
    ///   - initialDelay: The wait before the first retry.
    ///   - multiplier: How much longer each wait is than the one before. Defaults to `2`.
    ///   - maxCount: The maximum number of attempts, the first one included, so `4` is three
    ///     retries. Defaults to `UInt.max`, which never stops.
    ///   - maxDelay: The maximum duration to wait. Defaults to `Int.max` seconds.
    ///   - jitter: How each delay is randomized. Defaults to ``BackoffJitter/none``.
    /// - Returns: An `ExponentialBackoffStrategy` with those delays.
    ///
    /// Traps if `initialDelay` is negative, or if `multiplier` is less than `1` or isn't finite.
    public static func exponential(
        initialDelay: ContinuousClock.Duration, multiplier: Double = 2, maxCount: UInt = .max,
        maxDelay: ContinuousClock.Duration = .seconds(Int.max), jitter: BackoffJitter = .none
    ) -> ExponentialBackoffStrategy<Clock> {
        ExponentialBackoffStrategy(
            initialDelay: initialDelay, multiplier: multiplier, maxCount: maxCount,
            maxDelay: maxDelay, jitter: jitter)
    }

    /// Creates a binary exponential backoff strategy with a maximum retry count.
    ///
    /// The base duration for this strategy is set to 2, meaning the delay will double with each retry.
    ///
    /// - Parameters:
    ///   - maxCount: The maximum number of attempts. Defaults to `UInt.max`, which never stops.
    ///   - maxDelay: The maximum duration to wait.
    ///   - jitter: How each delay is randomized. Defaults to ``BackoffJitter/none``.
    /// - Returns: An `ExponentialBackoffStrategy` configured with a base of 2 and the provided maximum retry count.
    public static func binaryExponential(
        maxCount: UInt = .max, maxDelay: ContinuousClock.Duration = .seconds(Int.max),
        jitter: BackoffJitter = .none
    ) -> ExponentialBackoffStrategy<Clock> {
        ExponentialBackoffStrategy(base: 2, maxCount: maxCount, maxDelay: maxDelay, jitter: jitter)
    }
}

/// An exponential backoff strategy for retrying operations.
///
/// This actor waits longer between each retry until the maximum attempt count is reached. The
/// delays come from one of two schedules:
/// - `init(base:maxCount:maxDelay:jitter:)`: `base`, `base²`, `base³`, …, each converted to a
///   duration by the retry strategy's duration unit.
/// - ``init(initialDelay:multiplier:maxCount:maxDelay:jitter:)``: `initialDelay`,
///   `initialDelay × multiplier`, `initialDelay × multiplier²`, …, as durations already.
///
/// Every delay is capped at `maxDelay`. Hold on to the strategy and call ``reset()`` to start the
/// delays over, for example once a connection that was being retried is up again.
///
/// ## Example
/// ```swift
/// try await DeferredTask { /* some fallible work */ }
///     .retry(.backoff(.exponential(initialDelay: .seconds(1), multiplier: 2, maxDelay: .seconds(60))))
///     .execute()
/// ```
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public actor ExponentialBackoffStrategy<Clock: _Concurrency.Clock>: BackoffStrategy {
    /// How the delays grow.
    enum Schedule: Sendable {
        /// The nth attempt waits `durationUnit(base^n)`.
        case powers(base: UInt)
        /// The attempts wait `initial`, `initial × multiplier`, …; `next` is the coming wait, kept
        /// so that each one grows from the last without computing a power that could overflow.
        case geometric(initial: Clock.Duration, multiplier: Double, next: Clock.Duration)
    }

    var schedule: Schedule
    // A `UInt`, like `maxCount`: it only grows while below `maxCount`, so `+= 1` can't overflow, and the
    // count saturates at `UInt.max` when `maxCount` is `UInt.max` (no limit) rather than trapping.
    var count: UInt = 1
    let maxCount: UInt
    let maxDelay: Clock.Duration
    let jitter: BackoffJitter

    /// Creates a new exponential backoff strategy with the given base and maximum retry count.
    ///
    /// - Parameters:
    ///   - base: The base duration for the backoff, which will increase exponentially with each retry.
    ///   - maxCount: The maximum number of attempts. Defaults to `UInt.max`, which never stops.
    ///   - maxDelay: The maximum duration to wait.
    ///   - jitter: How each delay is randomized, after it is capped at `maxDelay`; the jittered
    ///     delay is capped at `maxDelay` too. Defaults to ``BackoffJitter/none``.
    public init(
        base: UInt, maxCount: UInt = .max, maxDelay: Clock.Duration, jitter: BackoffJitter = .none
    ) {
        self.schedule = .powers(base: base)
        self.maxCount = maxCount
        self.maxDelay = maxDelay
        self.jitter = jitter
    }

    /// Creates a new exponential backoff strategy with the given base and maximum retry count.
    ///
    /// - Parameters:
    ///   - base: The base duration for the backoff, which will increase exponentially with each retry.
    ///   - maxCount: The maximum number of attempts. Defaults to `UInt.max`, which never stops.
    ///   - maxDelay: The maximum duration to wait. Defaults to `Int.max` seconds.
    ///   - jitter: How each delay is randomized, after it is capped at `maxDelay`; the jittered
    ///     delay is capped at `maxDelay` too. Defaults to ``BackoffJitter/none``.
    public init(
        base: UInt, maxCount: UInt = .max, maxDelay: Clock.Duration = .seconds(Int.max),
        jitter: BackoffJitter = .none
    )
    where Clock.Duration == Duration {
        self.schedule = .powers(base: base)
        self.maxCount = maxCount
        self.maxDelay = maxDelay
        self.jitter = jitter
    }

    /// Creates an exponential backoff strategy that waits an initial delay, then multiplies it after
    /// each retry, up to a maximum delay.
    ///
    /// The waits are `initialDelay`, `initialDelay × multiplier`, `initialDelay × multiplier²`, …,
    /// each capped at `maxDelay`; once a wait reaches `maxDelay`, every later one is `maxDelay`.
    /// These are durations already, so the duration unit a ``RetryByBackoffStrategy`` passes to
    /// ``backoff(clock:durationUnit:)`` is ignored.
    ///
    /// ## Example
    /// ```swift
    /// let strategy = ExponentialBackoffStrategy<ContinuousClock>(
    ///     initialDelay: .milliseconds(500), multiplier: 1.5, maxCount: 6, maxDelay: .seconds(10))
    /// try await DeferredTask { /* some fallible work */ }
    ///     .retry(RetryByBackoffStrategy(strategy, clock: ContinuousClock()))
    ///     .execute()
    /// ```
    ///
    /// - Parameters:
    ///   - initialDelay: The wait before the first retry.
    ///   - multiplier: How much longer each wait is than the one before. Defaults to `2`.
    ///   - maxCount: The maximum number of attempts, the first one included, so `4` is three
    ///     retries. Defaults to `UInt.max`, which never stops.
    ///   - maxDelay: The maximum duration to wait. Defaults to `Int.max` seconds.
    ///   - jitter: How each delay is randomized, after it is capped at `maxDelay`; the jittered
    ///     delay is capped at `maxDelay` too. Defaults to ``BackoffJitter/none``.
    ///
    /// Traps if `initialDelay` is negative, or if `multiplier` is less than `1` or isn't finite.
    public init(
        initialDelay: Duration, multiplier: Double = 2, maxCount: UInt = .max,
        maxDelay: Duration = .seconds(Int.max), jitter: BackoffJitter = .none
    )
    where Clock.Duration == Duration {
        precondition(initialDelay >= .zero, "initialDelay must not be negative")
        precondition(
            multiplier.isFinite && multiplier >= 1, "multiplier must be finite and at least 1")
        self.schedule = .geometric(
            initial: initialDelay, multiplier: multiplier, next: initialDelay)
        self.maxCount = maxCount
        self.maxDelay = maxDelay
        self.jitter = jitter
    }

    /// Starts the delays over, as if no retry had happened yet.
    ///
    /// It also makes decorrelated jitter (``BackoffJitter/decorrelated(using:)``) forget its previous
    /// wait.
    public func reset() {
        count = 1
        if case .geometric(let initial, let multiplier, _) = schedule {
            schedule = .geometric(initial: initial, multiplier: multiplier, next: initial)
        }
        jitter.reset()
    }

    public func backoff<T: BinaryInteger>(clock: Clock, durationUnit: ClockDurationUnit<Clock, T>)
        async throws -> Bool
    {
        guard maxCount == .max || count < maxCount else { return false }
        let delay: Clock.Duration
        switch schedule {
            case .powers(let base):
                // Past what `T` holds, the delay is already beyond any cap.
                delay = T(exactly: pow(Double(base), Double(count))).map(durationUnit) ?? maxDelay
            case .geometric(let initial, let multiplier, let next):
                delay = next
                schedule = .geometric(
                    initial: initial, multiplier: multiplier,
                    next: next.multiplied(by: multiplier, upTo: maxDelay))
        }
        // Spent before the sleep, so a reset() during it isn't undone when the sleep ends.
        if count < .max { count += 1 }
        try await clock.sleep(for: jitter.jittered(min(delay, maxDelay), upTo: maxDelay))
        return true
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension DurationProtocol {
    /// This delay times `multiplier`, or `limit` once the product would reach it. A delay that is
    /// zero, or already at or past `limit`, stays as it is, so the product never overflows.
    fileprivate func multiplied(by multiplier: Double, upTo limit: Self) -> Self {
        guard self > .zero, self < limit else { return self }
        guard limit / self > multiplier else { return limit }
        // `DurationProtocol` can't be multiplied by a `Double`; `Duration` can. Only
        // `ExponentialBackoffStrategy.Schedule.geometric` calls this, and only the initializer
        // constrained to `Clock.Duration == Duration` makes that schedule, so both casts succeed.
        // `min` absorbs the rounding of a product that lands a hair past `limit`.
        return min((self as! Duration) * multiplier as! Self, limit)
    }
}
