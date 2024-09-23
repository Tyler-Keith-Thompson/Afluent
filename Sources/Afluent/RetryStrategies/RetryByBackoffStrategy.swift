//
//  RetryByBackoffStrategy.swift
//  Afluent
//
//  Created by Tyler Thompson on 9/19/24.
//

import Foundation

public typealias ClockDurationUnit<C: Clock, T: BinaryInteger> = @Sendable (T) -> C.Duration

extension RetryStrategy where Self == RetryByBackoffStrategy<ContinuousClock> {
    /// Creates a retry strategy using the provided backoff strategy and a continuous clock.
    ///
    /// This extension provides a convenient method to create a `RetryByBackoffStrategy` using a `ContinuousClock`.
    ///
    /// - Parameter strategy: The backoff strategy to use for retrying operations.
    /// - Returns: A `RetryByBackoffStrategy` configured with the provided `BackoffStrategy` and a `ContinuousClock`.
    public static func backoff(_ strategy: BackoffStrategy) -> RetryByBackoffStrategy<ContinuousClock> {
        RetryByBackoffStrategy(strategy, clock: ContinuousClock())
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
public actor RetryByBackoffStrategy<C: Clock>: RetryStrategy where C.Duration == Duration {
    let strategy: any BackoffStrategy
    let clock: C

    /// Creates a new retry strategy with the given backoff strategy and clock.
    ///
    /// - Parameters:
    ///   - strategy: The backoff strategy used to determine how to back off between retries.
    ///   - clock: The clock used to measure the time between retries.
    public init(_ strategy: some BackoffStrategy, clock: C) {
        self.strategy = strategy
        self.clock = clock
    }

    public func handle(error err: Error, beforeRetry: @Sendable (Error) async throws -> Void) async throws -> Bool {
        try await strategy.backoff(clock: clock, durationUnit: { (arg: Int) in .seconds(arg) })
    }
}

/// A protocol for implementing custom backoff strategies in retry mechanisms.
///
/// Types conforming to `BackoffStrategy` must implement logic for calculating delays between retry attempts.
/// The delay is determined using a clock and a duration unit.
public protocol BackoffStrategy: Sendable {
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
    func backoff<C: Clock, T: BinaryInteger>(clock: C, durationUnit: ClockDurationUnit<C, T>) async throws -> Bool
}

extension BackoffStrategy where Self == ExponentialBackoffStrategy {
    /// Creates an exponential backoff strategy with a configurable base and maximum retry count.
    ///
    /// - Parameters:
    ///   - base: The base duration for the backoff, which will exponentially increase with each retry.
    ///   - maxCount: The maximum number of retries allowed.
    /// - Returns: An `ExponentialBackoffStrategy` configured with the provided base and maximum retry count.
    public static func exponential(base: UInt, maxCount: UInt) -> ExponentialBackoffStrategy {
        ExponentialBackoffStrategy(base: base, maxCount: maxCount)
    }
    
    /// Creates a binary exponential backoff strategy with a maximum retry count.
    ///
    /// The base duration for this strategy is set to 2, meaning the delay will double with each retry.
    ///
    /// - Parameter maxCount: The maximum number of retries allowed.
    /// - Returns: An `ExponentialBackoffStrategy` configured with a base of 2 and the provided maximum retry count.
    public static func binaryExponential(maxCount: UInt) -> ExponentialBackoffStrategy {
        ExponentialBackoffStrategy(base: 2, maxCount: maxCount)
    }
}

/// An exponential backoff strategy for retrying operations.
///
/// This actor calculates exponential delays between retries based on a specified base value. With each retry,
/// the delay increases exponentially until the maximum retry count is reached.
public actor ExponentialBackoffStrategy: BackoffStrategy {
    let base: UInt
    var count = 1
    let maxCount: UInt
    
    /// Creates a new exponential backoff strategy with the given base and maximum retry count.
    ///
    /// - Parameters:
    ///   - base: The base duration for the backoff, which will increase exponentially with each retry.
    ///   - maxCount: The maximum number of retries allowed.
    public init(base: UInt, maxCount: UInt) {
        self.base = base
        self.maxCount = maxCount
    }
    
    public func backoff<C: Clock, T: BinaryInteger>(clock: C, durationUnit: ClockDurationUnit<C, T>) async throws -> Bool {
        guard count < maxCount else { return false }
        try await Task.sleep(for: durationUnit(T(pow(Double(base), Double(count)))), clock: clock)
        count += 1
        return true
    }
}
