//
//  AsynchronousUnitOfWorkCache.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Foundation

public typealias AUOWCache = AsynchronousUnitOfWorkCache
public typealias AnySendableReference = AnyObject & Sendable

/// A thread-safe cache for storing and sharing asynchronous units of work.
///
/// Store and retrieve reference-type, sendable units of work keyed by an integer. This cache is typically used by the ``shareFromCache(_:strategy:keys:)`` operator to deduplicate and share underlying work across consumers.
///
/// Use this cache to avoid redundant execution of identical units of work, especially those that are expensive or should only be performed once for a given key.
/// ## Example
/// ```swift
/// let cache = AUOWCache()
/// let work = DeferredTask { await fetchUser() }
///     .shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation, keys: "user42")
/// let _ = try await work.execute()
/// ```
public final class AsynchronousUnitOfWorkCache: @unchecked Sendable {
    let lock = NSRecursiveLock()
    var cache = [Int: any AsynchronousUnitOfWork & AnySendableReference]()

    public init() {}

    /// Retrieves a stored unit of work for the given key, if it exists in the cache.
    ///
    /// - Parameter key: The integer cache key associated with the unit of work.
    /// - Returns: The stored unit of work if present, or `nil` if none is cached.
    public func retrieve(
        keyedBy key: Int
    ) -> (any AsynchronousUnitOfWork & AnySendableReference)? {
        lock.lock()
        let fromCache = cache[key]
        lock.unlock()
        return fromCache
    }

    /// Stores a unit of work in the cache for the given key.
    ///
    /// If a unit of work already exists for the key, it is replaced with the provided one.
    ///
    /// - Parameters:
    ///   - unitOfWork: The unit of work to cache. Must be reference-type and sendable.
    ///   - key: The integer cache key to associate with the unit of work.
    /// - Returns: The cached unit of work (the same instance passed in).
    public func create<A: AsynchronousUnitOfWork & AnySendableReference>(
        unitOfWork: A, keyedBy key: Int
    ) -> A {
        lock.lock()
        cache[key] = unitOfWork
        lock.unlock()
        return unitOfWork
    }

    /// Retrieves the unit of work for the given key if present; otherwise, stores the provided unit of work and returns it.
    ///
    /// This is typically used to deduplicate work by sharing a single instance for the same key.
    ///
    /// - Parameters:
    ///   - unitOfWork: The unit of work to cache if a value does not yet exist for the key.
    ///   - key: The integer cache key to lookup or store under.
    /// - Returns: The cached or newly created unit of work.
    public func retrieveOrCreate<A: AsynchronousUnitOfWork & AnySendableReference>(
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

    /// Removes the cached unit of work for the given key, if present.
    ///
    /// This is used internally by cache strategies to clear results when a unit of work completes, fails, or is cancelled.
    ///
    /// - Parameter key: The integer cache key to clear.
    public func clearAsynchronousUnitOfWork(withKey key: Int) {
        lock.lock()
        defer { lock.unlock() }
        cache.removeValue(forKey: key)
    }

    /// Cancels all cached units of work and removes them from the cache upon deinitialization.
    ///
    /// This ensures no hanging work remains in memory if the cache is released.
    deinit {
        lock.lock()
        defer { lock.unlock() }
        cache.values.forEach { $0.cancel() }
        cache.removeAll()
    }
}

