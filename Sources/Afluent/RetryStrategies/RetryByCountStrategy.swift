//
//  RetryByCountStrategy.swift
//  Afluent
//
//  Created by Tyler Thompson on 9/19/24.
//

extension RetryStrategy where Self == RetryByCountStrategy {
    /// Creates a retry strategy that retries the operation up to a specified number of times.
    ///
    /// - Parameter count: The maximum number of retries allowed.
    /// - Returns: A `RetryByCountStrategy` configured to retry up to the specified count.
    ///
    /// - Note: The retry count will be decremented after each retry attempt, stopping when it reaches zero.
    public static func byCount(_ count: UInt) -> RetryByCountStrategy {
        return RetryByCountStrategy(retryCount: count)
    }
}

/// A `RetryStrategy` that limits the number of retry attempts.
///
/// This strategy retries an operation a specified number of times before giving up.
///
/// - Important: Once the retry count reaches zero, no further retries will be attempted.
public actor RetryByCountStrategy: RetryStrategy {
    /// The number of retries remaining.
    var retryCount: UInt

    /// Creates a new `RetryByCountStrategy` with the specified retry count.
    ///
    /// - Parameter retryCount: The maximum number of retries allowed.
    public init(retryCount: UInt) {
        self.retryCount = retryCount
    }

    public func handle(error err: Error, beforeRetry: @Sendable (Error) async throws -> Void)
        async throws -> Bool
    {
        guard retryCount > 0 else {
            return false
        }

        try await beforeRetry(err)
        decrementRetry()
        return true
    }

    func decrementRetry() {
        guard retryCount > 0 else { return }
        retryCount -= 1
    }
}
