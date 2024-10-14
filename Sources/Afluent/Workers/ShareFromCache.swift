//
//  ShareFromCache.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Foundation

extension AsynchronousUnitOfWork {
    func _shareFromCache(
        _ cache: AUOWCache, strategy: AUOWCache.Strategy, hasher: inout Hasher, fileId: String = "",
        function: String = "", line: UInt = 0, column: UInt = 0
    ) -> some AsynchronousUnitOfWork<Success> {
        hasher.combine(fileId)
        hasher.combine(function)
        hasher.combine(line)
        hasher.combine(column)
        let key = hasher.finalize()
        switch strategy {
            case .cacheUntilCompletionOrCancellation:
                return cache.retrieveOrCreate(
                    unitOfWork: handleEvents(
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
                    keyedBy: key)
        }
    }

    /// Shares data from the given cache based on a specified caching strategy and additional context information.
    ///
    /// - Parameters:
    ///   - cache: The cache from which to share data.
    ///   - strategy: The caching strategy to use.
    ///   - fileId: The ID of the file where this function is called. Defaults to `#fileID`.
    ///   - function: The name of the calling function. Defaults to `#function`.
    ///   - line: The line number where this function is called. Defaults to `#line`.
    ///   - column: The column where this function is called. Defaults to `#column`.
    /// - Returns: An asynchronous unit of work encapsulating the operation's success or failure.
    public func shareFromCache(
        _ cache: AUOWCache, strategy: AUOWCache.Strategy, fileId: String = #fileID,
        function: String = #function, line: UInt = #line, column: UInt = #column
    ) -> some AsynchronousUnitOfWork<Success> {
        var hasher = Hasher()
        return _shareFromCache(
            cache, strategy: strategy, hasher: &hasher, fileId: fileId, function: function,
            line: line, column: column)
    }

    /// Shares data from the given cache based on a specified caching strategy and hashable keys.
    ///
    /// - Parameters:
    ///   - cache: The cache from which to share data.
    ///   - strategy: The caching strategy to use.
    ///   - keys: One or more hashable keys used to look up the data in the cache.
    /// - Returns: An asynchronous unit of work encapsulating the operation's success or failure.
    public func shareFromCache<H0: Hashable>(
        _ cache: AUOWCache, strategy: AUOWCache.Strategy, keys k0: H0
    ) -> some AsynchronousUnitOfWork<Success> {
        var hasher = Hasher()
        hasher.combine(k0)
        return _shareFromCache(cache, strategy: strategy, hasher: &hasher)
    }

    /// Shares data from the given cache based on a specified caching strategy and hashable keys.
    ///
    /// - Parameters:
    ///   - cache: The cache from which to share data.
    ///   - strategy: The caching strategy to use.
    ///   - keys: One or more hashable keys used to look up the data in the cache.
    /// - Returns: An asynchronous unit of work encapsulating the operation's success or failure.
    public func shareFromCache<H0: Hashable, H1: Hashable>(
        _ cache: AUOWCache, strategy: AUOWCache.Strategy, keys k0: H0, _ k1: H1
    ) -> some AsynchronousUnitOfWork<Success> {
        var hasher = Hasher()
        hasher.combine(k0)
        hasher.combine(k1)
        return _shareFromCache(cache, strategy: strategy, hasher: &hasher)
    }

    /// Shares data from the given cache based on a specified caching strategy and hashable keys.
    ///
    /// - Parameters:
    ///   - cache: The cache from which to share data.
    ///   - strategy: The caching strategy to use.
    ///   - keys: One or more hashable keys used to look up the data in the cache.
    /// - Returns: An asynchronous unit of work encapsulating the operation's success or failure.
    public func shareFromCache<H0: Hashable, H1: Hashable, H2: Hashable>(
        _ cache: AUOWCache, strategy: AUOWCache.Strategy, keys k0: H0, _ k1: H1, _ k2: H2
    ) -> some AsynchronousUnitOfWork<Success> {
        var hasher = Hasher()
        hasher.combine(k0)
        hasher.combine(k1)
        hasher.combine(k2)
        return _shareFromCache(cache, strategy: strategy, hasher: &hasher)
    }

    /// Shares data from the given cache based on a specified caching strategy and hashable keys.
    ///
    /// - Parameters:
    ///   - cache: The cache from which to share data.
    ///   - strategy: The caching strategy to use.
    ///   - keys: One or more hashable keys used to look up the data in the cache.
    /// - Returns: An asynchronous unit of work encapsulating the operation's success or failure.
    public func shareFromCache<H0: Hashable, H1: Hashable, H2: Hashable, H3: Hashable>(
        _ cache: AUOWCache, strategy: AUOWCache.Strategy, keys k0: H0, _ k1: H1, _ k2: H2, _ k3: H3
    ) -> some AsynchronousUnitOfWork<Success> {
        var hasher = Hasher()
        hasher.combine(k0)
        hasher.combine(k1)
        hasher.combine(k2)
        hasher.combine(k3)
        return _shareFromCache(cache, strategy: strategy, hasher: &hasher)
    }

    /// Shares data from the given cache based on a specified caching strategy and hashable keys.
    ///
    /// - Parameters:
    ///   - cache: The cache from which to share data.
    ///   - strategy: The caching strategy to use.
    ///   - keys: One or more hashable keys used to look up the data in the cache.
    /// - Returns: An asynchronous unit of work encapsulating the operation's success or failure.
    public func shareFromCache<
        H0: Hashable, H1: Hashable, H2: Hashable, H3: Hashable, H4: Hashable
    >(
        _ cache: AUOWCache, strategy: AUOWCache.Strategy, keys k0: H0, _ k1: H1, _ k2: H2, _ k3: H3,
        _ k4: H4
    ) -> some AsynchronousUnitOfWork<Success> {
        var hasher = Hasher()
        hasher.combine(k0)
        hasher.combine(k1)
        hasher.combine(k2)
        hasher.combine(k3)
        hasher.combine(k4)
        return _shareFromCache(cache, strategy: strategy, hasher: &hasher)
    }

    /// Shares data from the given cache based on a specified caching strategy and hashable keys.
    ///
    /// - Parameters:
    ///   - cache: The cache from which to share data.
    ///   - strategy: The caching strategy to use.
    ///   - keys: One or more hashable keys used to look up the data in the cache.
    /// - Returns: An asynchronous unit of work encapsulating the operation's success or failure.
    public func shareFromCache<
        H0: Hashable, H1: Hashable, H2: Hashable, H3: Hashable, H4: Hashable, H5: Hashable
    >(
        _ cache: AUOWCache, strategy: AUOWCache.Strategy, keys k0: H0, _ k1: H1, _ k2: H2, _ k3: H3,
        _ k4: H4, _ k5: H5
    ) -> some AsynchronousUnitOfWork<Success> {
        var hasher = Hasher()
        hasher.combine(k0)
        hasher.combine(k1)
        hasher.combine(k2)
        hasher.combine(k3)
        hasher.combine(k4)
        hasher.combine(k5)
        return _shareFromCache(cache, strategy: strategy, hasher: &hasher)
    }

    /// Shares data from the given cache based on a specified caching strategy and hashable keys.
    ///
    /// - Parameters:
    ///   - cache: The cache from which to share data.
    ///   - strategy: The caching strategy to use.
    ///   - keys: One or more hashable keys used to look up the data in the cache.
    /// - Returns: An asynchronous unit of work encapsulating the operation's success or failure.
    public func shareFromCache<
        H0: Hashable, H1: Hashable, H2: Hashable, H3: Hashable, H4: Hashable, H5: Hashable,
        H6: Hashable
    >(
        _ cache: AUOWCache, strategy: AUOWCache.Strategy, keys k0: H0, _ k1: H1, _ k2: H2, _ k3: H3,
        _ k4: H4, _ k5: H5, _ k6: H6
    ) -> some AsynchronousUnitOfWork<Success> {
        var hasher = Hasher()
        hasher.combine(k0)
        hasher.combine(k1)
        hasher.combine(k2)
        hasher.combine(k3)
        hasher.combine(k4)
        hasher.combine(k5)
        hasher.combine(k6)
        return _shareFromCache(cache, strategy: strategy, hasher: &hasher)
    }

    /// Shares data from the given cache based on a specified caching strategy and hashable keys.
    ///
    /// - Parameters:
    ///   - cache: The cache from which to share data.
    ///   - strategy: The caching strategy to use.
    ///   - keys: One or more hashable keys used to look up the data in the cache.
    /// - Returns: An asynchronous unit of work encapsulating the operation's success or failure.
    public func shareFromCache<
        H0: Hashable, H1: Hashable, H2: Hashable, H3: Hashable, H4: Hashable, H5: Hashable,
        H6: Hashable, H7: Hashable
    >(
        _ cache: AUOWCache, strategy: AUOWCache.Strategy, keys k0: H0, _ k1: H1, _ k2: H2, _ k3: H3,
        _ k4: H4, _ k5: H5, _ k6: H6, _ k7: H7
    ) -> some AsynchronousUnitOfWork<Success> {
        var hasher = Hasher()
        hasher.combine(k0)
        hasher.combine(k1)
        hasher.combine(k2)
        hasher.combine(k3)
        hasher.combine(k4)
        hasher.combine(k5)
        hasher.combine(k6)
        hasher.combine(k7)
        return _shareFromCache(cache, strategy: strategy, hasher: &hasher)
    }

    /// Shares data from the given cache based on a specified caching strategy and hashable keys.
    ///
    /// - Parameters:
    ///   - cache: The cache from which to share data.
    ///   - strategy: The caching strategy to use.
    ///   - keys: One or more hashable keys used to look up the data in the cache.
    /// - Returns: An asynchronous unit of work encapsulating the operation's success or failure.
    public func shareFromCache<
        H0: Hashable, H1: Hashable, H2: Hashable, H3: Hashable, H4: Hashable, H5: Hashable,
        H6: Hashable, H7: Hashable, H8: Hashable
    >(
        _ cache: AUOWCache, strategy: AUOWCache.Strategy, keys k0: H0, _ k1: H1, _ k2: H2, _ k3: H3,
        _ k4: H4, _ k5: H5, _ k6: H6, _ k7: H7, _ k8: H8
    ) -> some AsynchronousUnitOfWork<Success> {
        var hasher = Hasher()
        hasher.combine(k0)
        hasher.combine(k1)
        hasher.combine(k2)
        hasher.combine(k3)
        hasher.combine(k4)
        hasher.combine(k5)
        hasher.combine(k6)
        hasher.combine(k7)
        hasher.combine(k8)
        return _shareFromCache(cache, strategy: strategy, hasher: &hasher)
    }

    /// Shares data from the given cache based on a specified caching strategy and hashable keys.
    ///
    /// - Parameters:
    ///   - cache: The cache from which to share data.
    ///   - strategy: The caching strategy to use.
    ///   - keys: One or more hashable keys used to look up the data in the cache.
    /// - Returns: An asynchronous unit of work encapsulating the operation's success or failure.
    public func shareFromCache<
        H0: Hashable, H1: Hashable, H2: Hashable, H3: Hashable, H4: Hashable, H5: Hashable,
        H6: Hashable, H7: Hashable, H8: Hashable, H9: Hashable
    >(
        _ cache: AUOWCache, strategy: AUOWCache.Strategy, keys k0: H0, _ k1: H1, _ k2: H2, _ k3: H3,
        _ k4: H4, _ k5: H5, _ k6: H6, _ k7: H7, _ k8: H8, _ 🐶: H9
    ) -> some AsynchronousUnitOfWork<Success> {
        var hasher = Hasher()
        hasher.combine(k0)
        hasher.combine(k1)
        hasher.combine(k2)
        hasher.combine(k3)
        hasher.combine(k4)
        hasher.combine(k5)
        hasher.combine(k6)
        hasher.combine(k7)
        hasher.combine(k8)
        hasher.combine(🐶)
        return _shareFromCache(cache, strategy: strategy, hasher: &hasher)
    }
}
