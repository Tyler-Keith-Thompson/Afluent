//
//  RetryStrategy.swift
//  Afluent
//
//  Created by Tyler Thompson on 9/19/24.
//

/// A strategy for handling errors and determining whether to retry an operation.
///
/// Conforming types must implement logic to determine if an operation should be retried after an error occurs.
/// This protocol also allows executing any pre-retry logic, such as logging or cleanup, before attempting a retry.
///
/// ## Example
/// ```swift
/// actor AlwaysRetryOnce: RetryStrategy {
///     private var hasRetried = false
///     func handle(error: Error, beforeRetry: @Sendable (Error) async throws -> Void) async throws -> Bool {
///         defer { hasRetried = true }
///         return !hasRetried
///     }
/// }
///
/// try await DeferredTask { /* some fallible work */ }
///     .retry(strategy: AlwaysRetryOnce())
///     .execute()
/// ```
public protocol RetryStrategy: Sendable {

    /// Determines whether an operation should be retried after encountering an error.
    ///
    /// - Parameters:
    ///   - error: The error that occurred during the operation.
    ///   - beforeRetry: A closure that is executed before a retry is attempted. The closure is passed the encountered error
    ///                  and can perform actions such as logging or cleanup before the retry is made. The closure itself is asynchronous
    ///                  and can throw errors if needed.
    ///
    /// - Returns: A Boolean value indicating whether a retry should be attempted (`true`) or not (`false`).
    ///
    /// - Throws: An error if either the retry strategy itself fails or if the `beforeRetry` closure encounters an error.
    func handle(error: Error, beforeRetry: @Sendable (Error) async throws -> Void) async throws
        -> Bool
}

extension RetryStrategy {
    /// Determines whether an operation should be retried after encountering an error.
    ///
    /// - Parameters:
    ///   - error: The error that occurred during the operation.
    ///
    /// - Returns: A Boolean value indicating whether a retry should be attempted (`true`) or not (`false`).
    ///
    /// - Throws: An error if either the retry strategy itself fails or if the `beforeRetry` closure encounters an error.
    public func handle(error err: Error) async throws -> Bool {
        try await handle(error: err, beforeRetry: { _ in })
    }
}

