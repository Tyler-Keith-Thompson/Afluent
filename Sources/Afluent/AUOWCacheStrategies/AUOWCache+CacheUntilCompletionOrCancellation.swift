//
//  AUOWCache+CacheUntilCompletionOrCancellation.swift
//
//
//  Created by Annalise Mariottini on 12/17/24.
//

import Foundation

extension AUOWCache {
    /// A caching strategy that retains a unit of work in the cache until it completes, fails, or is cancelled.
    ///
    /// This strategy is useful when you want to deduplicate concurrent requests for the same unit of work, ensuring that
    /// all consumers receive the same result, and the cached value is automatically cleared after completion or cancellation.
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
    ///
    /// // A unit of work that produces a String after a delay
    /// @Sendable func unitOfWork() -> some AsynchronousUnitOfWork<String> {
    ///     DeferredTask {
    ///         // ... expensive computation or network call ...
    ///         return "result"
    ///     }
    ///     .shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation)
    /// }
    ///
    /// // First execution stores the value in the cache
    /// let task1 = unitOfWork().execute()
    /// // Second execution (if started before completion) shares the cached value
    /// let task2 = unitOfWork().execute()
    ///
    /// // When task1 completes, the cache entry is cleared
    /// ```
    ///
    /// See also: ``AUOWCacheStrategy/cacheUntilCompletionOrCancellation``
    public struct CacheUntilCompletionOrCancellation: AUOWCacheStrategy {
        public func handle<A: AsynchronousUnitOfWork>(
            unitOfWork: A, keyedBy key: Int, storedIn cache: AUOWCache
        ) -> AnyAsynchronousUnitOfWork<A.Success> {
            cache.retrieveOrCreate(
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

extension AUOWCacheStrategy where Self == AUOWCache.CacheUntilCompletionOrCancellation {
    /// Returns the `.cacheUntilCompletionOrCancellation` strategy.
    ///
    /// Use this to cache a unit of work until it completes or is cancelled.
    ///
    /// See ``AUOWCache.CacheUntilCompletionOrCancellation`` for usage examples.
    public static var cacheUntilCompletionOrCancellation: Self {
        AUOWCache.CacheUntilCompletionOrCancellation()
    }
}
