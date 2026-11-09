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
public final class AsyncSequenceCache: Sendable {
    // Values leave the region by being returned, never released in it: releasing a sequence can run a `deinit`
    // that calls back into Afluent locks.
    private let state = CriticalState([Int: any AsyncSequence & Sendable]())

    /// A snapshot of the cached sequences.
    var cache: [Int: any AsyncSequence & Sendable] {
        state.withCriticalRegion { $0 }
    }

    public init() {}

    func retrieveOrCreate<A: AsyncSequence & Sendable>(
        unitOfWork: A, keyedBy key: Int
    ) -> A {
        // The replaced value, if any, is released once the region returns, outside the lock.
        let (fromCache, _) = state.withCriticalRegion { cache -> (A?, (any AsyncSequence & Sendable)?) in
            if let fromCache = cache[key] as? A { return (fromCache, nil) }
            return (nil, cache.updateValue(unitOfWork, forKey: key))
        }
        return fromCache ?? unitOfWork
    }

    func clearAsynchronousUnitOfWork(withKey key: Int) {
        // The removed value is released once the region returns, outside the lock.
        _ = state.withCriticalRegion { $0.removeValue(forKey: key) }
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
