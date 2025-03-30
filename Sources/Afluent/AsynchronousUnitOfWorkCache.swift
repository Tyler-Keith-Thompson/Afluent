////
////  AsynchronousUnitOfWorkCache.swift
////
////
////  Created by Tyler Thompson on 10/28/23.
////
//
//import Foundation
//
//public typealias AUOWCache = AsynchronousUnitOfWorkCache
//public typealias AnySendableReference = AnyObject & Sendable
//
///// A cache for asynchronous unit of work types.
///// A stored unit of work should be both `Sendable` and a reference type (e.g. a unit of work shared via the ``AsynchronousUnitOfWork/share()`` operator).
//public final class AsynchronousUnitOfWorkCache: @unchecked Sendable {
//    let lock = NSRecursiveLock()
//    var cache = [Int: any AsynchronousUnitOfWork & AnySendableReference]()
//
//    public init() {}
//
//    /// Returns a stored unit of work for the given key, if it exists in the cache.
//    public func retrieve(
//        keyedBy key: Int
//    ) -> (any AsynchronousUnitOfWork & AnySendableReference)? {
//        lock.lock()
//        let fromCache = cache[key]
//        lock.unlock()
//        return fromCache
//    }
//
//    /// Creates a new cached unit of work for the given key.
//    public func create<A: AsynchronousUnitOfWork & AnySendableReference>(
//        unitOfWork: A, keyedBy key: Int
//    ) -> A {
//        lock.lock()
//        cache[key] = unitOfWork
//        lock.unlock()
//        return unitOfWork
//    }
//
//    /// Either retrieves a stored unit of work for the given key, or creates a new one if no current one exists.
//    public func retrieveOrCreate<A: AsynchronousUnitOfWork & AnySendableReference>(
//        unitOfWork: A, keyedBy key: Int
//    ) -> A {
//        lock.lock()
//        if let fromCache: A = cache[key] as? A {
//            lock.unlock()
//            return fromCache
//        }
//
//        cache[key] = unitOfWork
//        lock.unlock()
//        return unitOfWork
//    }
//
//    public func clearAsynchronousUnitOfWork(withKey key: Int) {
//        lock.lock()
//        defer { lock.unlock() }
//        cache.removeValue(forKey: key)
//    }
//
//    deinit {
//        lock.lock()
//        defer { lock.unlock() }
//        cache.values.forEach { $0.cancel() }
//        cache.removeAll()
//    }
//}
