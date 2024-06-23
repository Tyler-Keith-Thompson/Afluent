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

    public init() { }

    func retrieveOrCreate<A: AsynchronousUnitOfWork & AnySendableReference>(unitOfWork: A, keyedBy key: Int) -> A {
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
    /// `Strategy` represents the available caching strategies for the `PublisherCache`.
    public enum Strategy {
        /// With the `.cacheUntilCompletionOrCancellation` strategy, the publisher cache
        /// retains the result until the publisher completes or the subscribers cancel
        /// their subscriptions.
        case cacheUntilCompletionOrCancellation
    }
}
