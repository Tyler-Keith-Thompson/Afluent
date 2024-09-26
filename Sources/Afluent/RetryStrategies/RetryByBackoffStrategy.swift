//
//  RetryByBackoffStrategy.swift
//  Afluent
//
//  Created by Tyler Thompson on 9/19/24.
//

import Foundation

public typealias ClockDurationUnit<C: Clock, T: BinaryInteger> = @Sendable (T) -> C.Duration

extension RetryStrategy where Self == RetryByBackoffStrategy<ExponentialBackoffStrategy<ContinuousClock>> {
    /// Creates a retry strategy using the provided backoff strategy and a continuous clock.
    ///
    /// This extension provides a convenient method to create a `RetryByBackoffStrategy` using a `ContinuousClock`.
    ///
    /// - Parameter strategy: The backoff strategy to use for retrying operations.
    /// - Returns: A `RetryByBackoffStrategy` configured with the provided `BackoffStrategy` and a `ContinuousClock`.
    public static func backoff(_ strategy: ExponentialBackoffStrategy<ContinuousClock>) -> RetryByBackoffStrategy<ExponentialBackoffStrategy<ContinuousClock>> {
        RetryByBackoffStrategy(strategy, clock: ContinuousClock(), durationUnit: Duration.seconds)
    }
}

/// A retry strategy using a specified backoff strategy and clock.
///
/// This actor manages retry attempts with a configurable `BackoffStrategy` and clock. It uses the clock to calculate
/// the time delays between retries, allowing more fine-grained control over the timing of retries based on the provided
/// backoff strategy.
///
/// - Parameters:
///   - C: The type of `Clock` used for measuring time between retries.
/// - Note: This actor conforms to `RetryStrategy` and is used to manage retries based on time delays.
public actor RetryByBackoffStrategy<Strategy: BackoffStrategy>: RetryStrategy {
    let strategy: Strategy
    let clock: Strategy.Clock
    let durationUnit: ClockDurationUnit<Strategy.Clock, Int>

    /// Creates a new retry strategy with the given backoff strategy and clock.
    ///
    /// - Parameters:
    ///   - strategy: The backoff strategy used to determine how to back off between retries.
    ///   - clock: The clock used to measure the time between retries.
    public init(_ strategy: Strategy, clock: Strategy.Clock, durationUnit: @escaping ClockDurationUnit<Strategy.Clock, Int>) {
        self.strategy = strategy
        self.clock = clock
        self.durationUnit = durationUnit
    }

    public func handle(error err: Error, beforeRetry: @Sendable (Error) async throws -> Void) async throws -> Bool {
        try await strategy.backoff(clock: clock, durationUnit: durationUnit)
    }
}

/// A protocol for implementing custom backoff strategies in retry mechanisms.
///
/// Types conforming to `BackoffStrategy` must implement logic for calculating delays between retry attempts.
/// The delay is determined using a clock and a duration unit.
public protocol BackoffStrategy<Clock>: Sendable where Clock: _Concurrency.Clock {
    associatedtype Clock
    /// Calculates the delay between retries using a clock and a duration unit.
    ///
    /// This method allows for custom backoff strategies based on a clock and a duration unit. The delay between retries
    /// is determined by the combination of these two parameters.
    ///
    /// - Parameters:
    ///   - clock: The clock used to measure the time between retries.
    ///   - durationUnit: A closure that converts an integer value to a clock duration.
    ///
    /// - Returns: A Boolean value indicating whether a retry should be attempted (`true`) or not (`false`).
    /// - Throws: Any error encountered during the backoff process.
    func backoff<T: BinaryInteger>(clock: Clock, durationUnit: ClockDurationUnit<Clock, T>) async throws -> Bool
}

extension BackoffStrategy where Self == ExponentialBackoffStrategy<ContinuousClock> {
    /// Creates an exponential backoff strategy with a configurable base and maximum retry count.
    ///
    /// - Parameters:
    ///   - base: The base duration for the backoff, which will exponentially increase with each retry.
    ///   - maxCount: The maximum number of retries allowed.
    /// - Returns: An `ExponentialBackoffStrategy` configured with the provided base and maximum retry count.
    public static func exponential(base: UInt, maxCount: UInt) -> ExponentialBackoffStrategy<Clock> {
        ExponentialBackoffStrategy(base: base, maxCount: maxCount)
    }
    
    /// Creates a binary exponential backoff strategy with a maximum retry count.
    ///
    /// The base duration for this strategy is set to 2, meaning the delay will double with each retry.
    ///
    /// - Parameter maxCount: The maximum number of retries allowed.
    /// - Returns: An `ExponentialBackoffStrategy` configured with a base of 2 and the provided maximum retry count.
    public static func binaryExponential(maxCount: UInt) -> ExponentialBackoffStrategy<Clock> {
        ExponentialBackoffStrategy(base: 2, maxCount: maxCount)
    }
}

/// An exponential backoff strategy for retrying operations.
///
/// This actor calculates exponential delays between retries based on a specified base value. With each retry,
/// the delay increases exponentially until the maximum retry count is reached.
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
    public init(base: UInt, maxCount: UInt, maxDelay: Clock.Duration = .seconds(Int.max)) where Clock.Duration == Duration {
        self.base = base
        self.maxCount = maxCount
        self.maxDelay = maxDelay
    }
    
    public func backoff<T: BinaryInteger>(clock: Clock, durationUnit: ClockDurationUnit<Clock, T>) async throws -> Bool {
        guard count < maxCount else { return false }
        try await clock.sleep(for: min(durationUnit(T(pow(Double(base), Double(count)))), maxDelay))
        count += 1
        return true
    }
}
