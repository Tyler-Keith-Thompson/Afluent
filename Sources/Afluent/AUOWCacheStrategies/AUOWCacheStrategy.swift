//
//  AUOWCache+Strategy.swift
//
//
//  Created by Annalise Mariottini on 12/17/24.
//

import Foundation

/// Represents a cache strategy for use with ``AUOWCache``.
///
/// Conforming types determine how units of work are stored, reused, or cancelled within the cache.
///
/// > Tip: Use or extend built-in strategies like ``AUOWCache.CancelAndRetry`` or ``AUOWCache.CacheUntilCompletionOrCancellation`` for common needs, or create a custom strategy for specialized scenarios.
///
/// ## Example
///
/// ```swift
/// struct NeverCacheStrategy: AUOWCacheStrategy {
///     func handle<A: AsynchronousUnitOfWork>(unitOfWork: A, keyedBy key: Int, storedIn cache: AUOWCache) -> AnyAsynchronousUnitOfWork<A.Success> {
///         unitOfWork.eraseToAnyUnitOfWork()
///     }
/// }
///
/// let cache = AUOWCache()
/// let myStrategy = NeverCacheStrategy()
/// let task = DeferredTask { "value" }
///     .shareFromCache(cache, strategy: myStrategy)
///
/// // Alternatively, use built-in strategies like:
/// // .shareFromCache(cache, strategy: .cancelAndRestart)
/// ```
public protocol AUOWCacheStrategy {
    /// Performs strategy-specific logic to store or retrieve an asynchronous unit of work in the cache.
    ///
    /// - Parameters:
    ///   - unitOfWork: The unit of work being evaluated or started.
    ///   - key: The hashed cache key for the unit of work.
    ///   - cache: The cache instance in which to store or from which to retrieve work.
    /// - Returns: An erased asynchronous unit of work. The specifics depend on the strategy implementation.
    func handle<A: AsynchronousUnitOfWork>(
        unitOfWork: A, keyedBy key: Int, storedIn cache: AUOWCache
    ) -> AnyAsynchronousUnitOfWork<A.Success>
}

