//
//  AsynchronousUnitOfWorkCache.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Foundation

public typealias AUOWCache = AsynchronousUnitOfWorkCache
typealias AnySendableReference = AnyObject & Sendable

public final class AsynchronousUnitOfWorkCache: @unchecked Sendable {
    let lock = NSRecursiveLock()
    var cache = [Int: any AsynchronousUnitOfWork & AnySendableReference]()

    public init() {}

    func retrieve(
        keyedBy key: Int
    ) -> (any AsynchronousUnitOfWork & AnySendableReference)? {
        lock.lock()
        let fromCache = cache[key]
        lock.unlock()
        return fromCache
    }

    func create<A: AsynchronousUnitOfWork & AnySendableReference>(
        unitOfWork: A, keyedBy key: Int
    ) -> A {
        lock.lock()
        cache[key] = unitOfWork
        lock.unlock()
        return unitOfWork
    }

    func retrieveOrCreate<A: AsynchronousUnitOfWork & AnySendableReference>(
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
        cache.values.forEach { $0.cancel() }
        cache.removeAll()
    }
}

extension AsynchronousUnitOfWorkCache {
    /// `Strategy` represents the available caching strategies for the `AsynchronousUnitOfWorkCache`.
    public enum Strategy {
        /// With the `.cacheUntilCompletionOrCancellation` strategy, the cache
        /// retains the result until the unit of work completes or is cancelled.
        case cacheUntilCompletionOrCancellation
        /// This strategy indicates that any existing work should be cancelled before restarting the upstream work again.
        case cancelAndRestart
    }
}
