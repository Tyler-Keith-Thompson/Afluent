//
//  AUOWCache+CancelAndRetry.swift
//
//
//  Created by Annalise Mariottini on 12/17/24.
//

import Foundation

extension AUOWCache {
    /// A caching strategy that cancels any existing in-flight unit of work for a key, then starts the new one.
    ///
    /// This strategy is useful when you want to ensure only the latest requested unit of work for a given key is running, and any prior work is cancelled.
    ///
    /// The cached entry is cleared on:
    /// - successful completion (output received)
    /// - error thrown
    /// - cancellation
    ///
    /// ## Example
    ///
    /// ```swift
    /// let cache = AUOWCache()
    /// let clock = TestClock()
    ///
    /// // A unit of work that produces a String after a delay
    /// @Sendable func unitOfWork() -> some AsynchronousUnitOfWork<String> {
    ///     DeferredTask {
    ///         UUID().uuidString
    ///     }
    ///     .delay(for: .milliseconds(10), clock: clock)
    ///     .shareFromCache(cache, strategy: .cancelAndRestart)
    /// }
    ///
    /// // First execution starts the work
    /// async let r1 = Result { try await unitOfWork().execute() }
    /// // Second execution before the first completes cancels the previous one
    /// async let r2 = Result { try await unitOfWork().execute() }
    ///
    /// await clock.advance(by: .milliseconds(11))
    /// let result1 = await r1
    /// let result2 = await r2
    ///
    /// // result1 should throw CancellationError, result2 completes successfully
    /// ```
    ///
    /// See also: ``AUOWCacheStrategy/cancelAndRestart``
    public struct CancelAndRetry: AUOWCacheStrategy {
        /// Handles the unit of work for this strategy, cancelling any in-flight work with the same key and starting the new one.
        ///
        /// - Parameters:
        ///   - unitOfWork: The unit of work to perform.
        ///   - key: The cache key associated with the unit of work.
        ///   - cache: The cache to use for sharing or cancelling work.
        /// - Returns: An asynchronous unit of work that will clear its cache entry after completion, error, or cancellation.
        public func handle<A: AsynchronousUnitOfWork>(
            unitOfWork: A, keyedBy key: Int, storedIn cache: AUOWCache
        ) -> AnyAsynchronousUnitOfWork<A.Success> {
            if let cachedWork = cache.retrieve(keyedBy: key) {
                cachedWork.cancel()
            }
            return cache.create(
                unitOfWork: unitOfWork.handleEvents(
                    receiveOutput: { [weak cache] _ in
                        cache?.clearAsynchronousUnitOfWork(withKey: key)
                    },
                    receiveError: { [weak cache] _ in
                        cache?.clearAsynchronousUnitOfWork(withKey: key)
                    },
                    receiveCancel: { [weak cache] in
                        cache?.clearAsynchronousUnitOfWork(withKey: key)
                    }
                ).share(),
                keyedBy: key
            ).eraseToAnyUnitOfWork()
        }
    }
}

extension AUOWCacheStrategy where Self == AUOWCache.CancelAndRetry {
    /// Returns the `.cancelAndRestart` strategy.
    ///
    /// Use this to cancel any in-flight unit of work for a given key before starting the new one. See ``AUOWCache.CancelAndRetry`` for a usage example.
    public static var cancelAndRestart: Self { AUOWCache.CancelAndRetry() }
}
