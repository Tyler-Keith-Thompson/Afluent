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
    /// ```
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
/// ```
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
/// ```
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
    ///   - maxCount: The maximum number of retries allowed.
    ///   - maxDelay: The maximum duration to wait.
    /// - Returns: An `ExponentialBackoffStrategy` configured with the provided base and maximum retry count.
    public static func exponential(
        base: UInt, maxCount: UInt, maxDelay: ContinuousClock.Duration = .seconds(Int.max)
    ) -> ExponentialBackoffStrategy<Clock> {
        ExponentialBackoffStrategy(base: base, maxCount: maxCount, maxDelay: maxDelay)
    }

    /// Creates a binary exponential backoff strategy with a maximum retry count.
    ///
    /// The base duration for this strategy is set to 2, meaning the delay will double with each retry.
    ///
    /// - Parameters:
    ///   - maxCount: The maximum number of retries allowed.
    ///   - maxDelay: The maximum duration to wait.
    /// - Returns: An `ExponentialBackoffStrategy` configured with a base of 2 and the provided maximum retry count.
    public static func binaryExponential(
        maxCount: UInt, maxDelay: ContinuousClock.Duration = .seconds(Int.max)
    ) -> ExponentialBackoffStrategy<Clock> {
        ExponentialBackoffStrategy(base: 2, maxCount: maxCount, maxDelay: maxDelay)
    }
}

/// An exponential backoff strategy for retrying operations.
///
/// This actor calculates exponential delays between retries based on a specified base value. With each retry,
/// the delay increases exponentially until the maximum retry count is reached.
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public actor ExponentialBackoffStrategy<Clock: _Concurrency.Clock>: BackoffStrategy {
    let base: UInt
    var count = 1
    let maxCount: UInt
    let maxDelay: Clock.Duration

    /// Creates a new exponential backoff strategy with the given base and maximum retry count.
    ///
    /// - Parameters:
    ///   - base: The base duration for the backoff, which will increase exponentially with each retry.
    ///   - maxCount: The maximum number of retries allowed.
    ///   - maxDelay: The maximum duration to wait.
    public init(base: UInt, maxCount: UInt, maxDelay: Clock.Duration) {
        self.base = base
        self.maxCount = maxCount
        self.maxDelay = maxDelay
    }

    /// Creates a new exponential backoff strategy with the given base and maximum retry count.
    ///
    /// - Parameters:
    ///   - base: The base duration for the backoff, which will increase exponentially with each retry.
    ///   - maxCount: The maximum number of retries allowed.
    ///   - maxDelay: The maximum duration to wait.
    public init(base: UInt, maxCount: UInt, maxDelay: Clock.Duration = .seconds(Int.max))
    where Clock.Duration == Duration {
        self.base = base
        self.maxCount = maxCount
        self.maxDelay = maxDelay
    }

    public func backoff<T: BinaryInteger>(clock: Clock, durationUnit: ClockDurationUnit<Clock, T>)
        async throws -> Bool
    {
        guard count < maxCount else { return false }
        try await clock.sleep(for: min(durationUnit(T(pow(Double(base), Double(count)))), maxDelay))
        count += 1
        return true
    }
}

