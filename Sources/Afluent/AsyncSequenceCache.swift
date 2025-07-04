//
//  AsyncSequenceCache.swift
//  Afluent
//
//  Created by Tyler Thompson on 10/13/24.
//

import Foundation

/// A thread-safe cache for sharing async sequences by integer key.
/// This cache is commonly used with the `shareFromCache` operator to reuse sequences.
///
/// ## Example
/// ```swift
/// let cache = AsyncSequenceCache()
/// let sequence = fetchData() // Some async sequence
/// let shared = sequence.shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation, keys: "myKey")
/// for await value in shared { print(value) }
/// ```
public final class AsyncSequenceCache: @unchecked Sendable {
    let lock = NSRecursiveLock()
    var cache = [Int: any AsyncSequence]()

    /// Creates a new, empty async sequence cache.
    public init() {}

    func retrieveOrCreate<A: AsyncSequence>(
        unitOfWork: A, keyedBy key: Int
    ) -> A {
        lock.lock()
        if let fromCache: A = cache[key] as? A {
            lock.unlock()
            return fromCache
        }

        cache[key] = unitOfWork
        lock.unlock()
        return unitOfWork
    }

    func clearAsynchronousUnitOfWork(withKey key: Int) {
        lock.lock()
        defer { lock.unlock() }
        cache.removeValue(forKey: key)
    }

    /// Removes all cached sequences when the cache is deallocated.
    deinit {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }
}

extension AsyncSequenceCache {
    /// `Strategy` represents the available caching strategies for the `AsyncSequenceCache`.
    /// These strategies determine how long the cache retains the async sequences.
    public enum Strategy {
        /// With the `.cacheUntilCompletionOrCancellation` strategy, the cache
        /// retains the result until the sequence completes or is canceled.
        /// This strategy is used when it is desirable to keep the cached sequence
        /// active only for its lifetime, releasing it once it finishes or is cancelled.
        case cacheUntilCompletionOrCancellation
    }
}
