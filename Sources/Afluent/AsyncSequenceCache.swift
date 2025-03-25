//
//  AsyncSequenceCache.swift
//  Afluent
//
//  Created by Tyler Thompson on 10/13/24.
//

import Foundation

public final class AsyncSequenceCache: @unchecked Sendable {
    let lock = NSRecursiveLock()
    var cache = [Int: any AsyncSequence]()

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

    deinit {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }
}

extension AsyncSequenceCache {
    /// `Strategy` represents the available caching strategies for the `AsyncSequenceCache`.
    public enum Strategy {
        /// With the `.cacheUntilCompletionOrCancellation` strategy, the cache
        /// retains the result until the sequence completes or is canceled.
        case cacheUntilCompletionOrCancellation
    }
}
