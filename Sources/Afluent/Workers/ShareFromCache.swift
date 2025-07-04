//
//  ShareFromCache.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Foundation

extension AsynchronousUnitOfWork {
    func _shareFromCache(
        _ cache: AUOWCache, strategy: any AUOWCacheStrategy, hasher: inout Hasher,
        fileId: String = "",
        function: String = "", line: UInt = 0, column: UInt = 0
    ) -> some AsynchronousUnitOfWork<Success> {
        hasher.combine(fileId)
        hasher.combine(function)
        hasher.combine(line)
        hasher.combine(column)
        let key = hasher.finalize()

        return strategy.handle(unitOfWork: self, keyedBy: key, storedIn: cache)
    }

    /// Shares the result of this unit of work from the given cache using the specified strategy and call-site context (file, function, line, column).
    ///
    /// Use this operator to ensure that the same cache entry is used for identical call sites, preventing duplicate work and sharing cached results.
    ///
    /// ## Example
    /// ```
    /// let cache = AUOWCache()
    /// let shared = DeferredTask { UUID() }
    ///     .shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation)
    /// async let a = shared.execute()
    /// async let b = shared.execute()
    /// let (val1, val2) = try await (a, b)
    /// // val1 and val2 are guaranteed to be identical (from cache)
    /// ```
    ///
    /// - Parameters:
    ///   - cache: The cache to share results from.
    ///   - strategy: The caching strategy.
    ///   - fileId: Call site file identifier (default: #fileID).
    ///   - function: Caller function (default: #function).
    ///   - line: Line number (default: #line).
    ///   - column: Column number (default: #column).
    /// - Returns: An `AsynchronousUnitOfWork` that shares its results from cache.
    /// - Important: This operator should generally be placed at the end of an operator chain. Any operators applied after `shareFromCache` will not be shared and may result in duplicated work or side effects.
    public func shareFromCache(
        _ cache: AUOWCache, strategy: any AUOWCacheStrategy, fileId: String = #fileID,
        function: String = #function, line: UInt = #line, column: UInt = #column
    ) -> some AsynchronousUnitOfWork<Success> {
        var hasher = Hasher()
        return _shareFromCache(
            cache, strategy: strategy, hasher: &hasher, fileId: fileId, function: function,
            line: line, column: column)
    }

    /// Shares the result of this unit of work from the given cache using the specified strategy and custom cache keys.
    ///
    /// Use this operator to share or de-duplicate expensive work based on custom, hashable cache keys.
    ///
    /// ## Example
    /// ```
    /// let cache = AUOWCache()
    /// let shared = DeferredTask { UUID() }
    ///     .shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation, keys: "user42")
    /// async let a = shared.execute()
    /// async let b = shared.execute()
    /// let (val1, val2) = try await (a, b)
    /// // val1 and val2 are guaranteed to be identical (from cache)
    /// ```
    ///
    /// - Parameters:
    ///   - cache: The cache to share results from.
    ///   - strategy: The caching strategy.
    ///   - keys: Hashable key(s) to identify the cache entry.
    /// - Returns: An `AsynchronousUnitOfWork` that shares its results from cache.
    /// - Important: This operator should generally be placed at the end of an operator chain. Any operators applied after `shareFromCache` will not be shared and may result in duplicated work or side effects.
    public func shareFromCache<H0: Hashable>(
        _ cache: AUOWCache, strategy: any AUOWCacheStrategy, keys k0: H0
    ) -> some AsynchronousUnitOfWork<Success> {
        var hasher = Hasher()
        hasher.combine(k0)
        return _shareFromCache(cache, strategy: strategy, hasher: &hasher)
    }

    /// Shares the result of this unit of work from the given cache using the specified strategy and custom cache keys.
    ///
    /// Use this operator to share or de-duplicate expensive work based on custom, hashable cache keys.
    ///
    /// ## Example
    /// ```
    /// let cache = AUOWCache()
    /// let shared = DeferredTask { UUID() }
    ///     .shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation, keys: "user", 42)
    /// async let a = shared.execute()
    /// async let b = shared.execute()
    /// let (val1, val2) = try await (a, b)
    /// // val1 and val2 are guaranteed to be identical (from cache)
    /// ```
    ///
    /// - Parameters:
    ///   - cache: The cache to share results from.
    ///   - strategy: The caching strategy.
    ///   - keys: Hashable key(s) to identify the cache entry.
    /// - Returns: An `AsynchronousUnitOfWork` that shares its results from cache.
    /// - Important: This operator should generally be placed at the end of an operator chain. Any operators applied after `shareFromCache` will not be shared and may result in duplicated work or side effects.
    public func shareFromCache<H0: Hashable, H1: Hashable>(
        _ cache: AUOWCache, strategy: any AUOWCacheStrategy, keys k0: H0, _ k1: H1
    ) -> some AsynchronousUnitOfWork<Success> {
        var hasher = Hasher()
        hasher.combine(k0)
        hasher.combine(k1)
        return _shareFromCache(cache, strategy: strategy, hasher: &hasher)
    }

    /// Shares the result of this unit of work from the given cache using the specified strategy and custom cache keys.
    ///
    /// Use this operator to share or de-duplicate expensive work based on custom, hashable cache keys.
    ///
    /// ## Example
    /// ```
    /// let cache = AUOWCache()
    /// let shared = DeferredTask { UUID() }
    ///     .shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation, keys: "user", 42, "session")
    /// async let a = shared.execute()
    /// async let b = shared.execute()
    /// let (val1, val2) = try await (a, b)
    /// // val1 and val2 are guaranteed to be identical (from cache)
    /// ```
    ///
    /// - Parameters:
    ///   - cache: The cache to share results from.
    ///   - strategy: The caching strategy.
    ///   - keys: Hashable key(s) to identify the cache entry.
    /// - Returns: An `AsynchronousUnitOfWork` that shares its results from cache.
    /// - Important: This operator should generally be placed at the end of an operator chain. Any operators applied after `shareFromCache` will not be shared and may result in duplicated work or side effects.
    public func shareFromCache<H0: Hashable, H1: Hashable, H2: Hashable>(
        _ cache: AUOWCache, strategy: any AUOWCacheStrategy, keys k0: H0, _ k1: H1, _ k2: H2
    ) -> some AsynchronousUnitOfWork<Success> {
        var hasher = Hasher()
        hasher.combine(k0)
        hasher.combine(k1)
        hasher.combine(k2)
        return _shareFromCache(cache, strategy: strategy, hasher: &hasher)
    }

    /// Shares the result of this unit of work from the given cache using the specified strategy and custom cache keys.
    ///
    /// Use this operator to share or de-duplicate expensive work based on custom, hashable cache keys.
    ///
    /// ## Example
    /// ```
    /// let cache = AUOWCache()
    /// let shared = DeferredTask { UUID() }
    ///     .shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation, keys: "user", 42, "session", 1)
    /// async let a = shared.execute()
    /// async let b = shared.execute()
    /// let (val1, val2) = try await (a, b)
    /// // val1 and val2 are guaranteed to be identical (from cache)
    /// ```
    ///
    /// - Parameters:
    ///   - cache: The cache to share results from.
    ///   - strategy: The caching strategy.
    ///   - keys: Hashable key(s) to identify the cache entry.
    /// - Returns: An `AsynchronousUnitOfWork` that shares its results from cache.
    /// - Important: This operator should generally be placed at the end of an operator chain. Any operators applied after `shareFromCache` will not be shared and may result in duplicated work or side effects.
    public func shareFromCache<H0: Hashable, H1: Hashable, H2: Hashable, H3: Hashable>(
        _ cache: AUOWCache, strategy: any AUOWCacheStrategy, keys k0: H0, _ k1: H1, _ k2: H2, _ k3: H3
    ) -> some AsynchronousUnitOfWork<Success> {
        var hasher = Hasher()
        hasher.combine(k0)
        hasher.combine(k1)
        hasher.combine(k2)
        hasher.combine(k3)
        return _shareFromCache(cache, strategy: strategy, hasher: &hasher)
    }

    /// Shares the result of this unit of work from the given cache using the specified strategy and custom cache keys.
    ///
    /// Use this operator to share or de-duplicate expensive work based on custom, hashable cache keys.
    ///
    /// ## Example
    /// ```
    /// let cache = AUOWCache()
    /// let shared = DeferredTask { UUID() }
    ///     .shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation, keys: "user", 42, "session", 1, "extra")
    /// async let a = shared.execute()
    /// async let b = shared.execute()
    /// let (val1, val2) = try await (a, b)
    /// // val1 and val2 are guaranteed to be identical (from cache)
    /// ```
    ///
    /// - Parameters:
    ///   - cache: The cache to share results from.
    ///   - strategy: The caching strategy.
    ///   - keys: Hashable key(s) to identify the cache entry.
    /// - Returns: An `AsynchronousUnitOfWork` that shares its results from cache.
    /// - Important: This operator should generally be placed at the end of an operator chain. Any operators applied after `shareFromCache` will not be shared and may result in duplicated work or side effects.
    public func shareFromCache<
        H0: Hashable, H1: Hashable, H2: Hashable, H3: Hashable, H4: Hashable
    >(
        _ cache: AUOWCache, strategy: any AUOWCacheStrategy, keys k0: H0, _ k1: H1, _ k2: H2, _ k3: H3,
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

    /// Shares the result of this unit of work from the given cache using the specified strategy and custom cache keys.
    ///
    /// Use this operator to share or de-duplicate expensive work based on custom, hashable cache keys.
    ///
    /// ## Example
    /// ```
    /// let cache = AUOWCache()
    /// let shared = DeferredTask { UUID() }
    ///     .shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation, keys: "user", 42, "session", 1, "extra", 99)
    /// async let a = shared.execute()
    /// async let b = shared.execute()
    /// let (val1, val2) = try await (a, b)
    /// // val1 and val2 are guaranteed to be identical (from cache)
    /// ```
    ///
    /// - Parameters:
    ///   - cache: The cache to share results from.
    ///   - strategy: The caching strategy.
    ///   - keys: Hashable key(s) to identify the cache entry.
    /// - Returns: An `AsynchronousUnitOfWork` that shares its results from cache.
    /// - Important: This operator should generally be placed at the end of an operator chain. Any operators applied after `shareFromCache` will not be shared and may result in duplicated work or side effects.
    public func shareFromCache<
        H0: Hashable, H1: Hashable, H2: Hashable, H3: Hashable, H4: Hashable, H5: Hashable
    >(
        _ cache: AUOWCache, strategy: any AUOWCacheStrategy, keys k0: H0, _ k1: H1, _ k2: H2, _ k3: H3,
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

    /// Shares the result of this unit of work from the given cache using the specified strategy and custom cache keys.
    ///
    /// Use this operator to share or de-duplicate expensive work based on custom, hashable cache keys.
    ///
    /// ## Example
    /// ```
    /// let cache = AUOWCache()
    /// let shared = DeferredTask { UUID() }
    ///     .shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation, keys: "user", 42, "session", 1, "extra", 99, "flag")
    /// async let a = shared.execute()
    /// async let b = shared.execute()
    /// let (val1, val2) = try await (a, b)
    /// // val1 and val2 are guaranteed to be identical (from cache)
    /// ```
    ///
    /// - Parameters:
    ///   - cache: The cache to share results from.
    ///   - strategy: The caching strategy.
    ///   - keys: Hashable key(s) to identify the cache entry.
    /// - Returns: An `AsynchronousUnitOfWork` that shares its results from cache.
    /// - Important: This operator should generally be placed at the end of an operator chain. Any operators applied after `shareFromCache` will not be shared and may result in duplicated work or side effects.
    public func shareFromCache<
        H0: Hashable, H1: Hashable, H2: Hashable, H3: Hashable, H4: Hashable, H5: Hashable,
        H6: Hashable
    >(
        _ cache: AUOWCache, strategy: any AUOWCacheStrategy, keys k0: H0, _ k1: H1, _ k2: H2, _ k3: H3,
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

    /// Shares the result of this unit of work from the given cache using the specified strategy and custom cache keys.
    ///
    /// Use this operator to share or de-duplicate expensive work based on custom, hashable cache keys.
    ///
    /// ## Example
    /// ```
    /// let cache = AUOWCache()
    /// let shared = DeferredTask { UUID() }
    ///     .shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation, keys: "user", 42, "session", 1, "extra", 99, "flag", true)
    /// async let a = shared.execute()
    /// async let b = shared.execute()
    /// let (val1, val2) = try await (a, b)
    /// // val1 and val2 are guaranteed to be identical (from cache)
    /// ```
    ///
    /// - Parameters:
    ///   - cache: The cache to share results from.
    ///   - strategy: The caching strategy.
    ///   - keys: Hashable key(s) to identify the cache entry.
    /// - Returns: An `AsynchronousUnitOfWork` that shares its results from cache.
    /// - Important: This operator should generally be placed at the end of an operator chain. Any operators applied after `shareFromCache` will not be shared and may result in duplicated work or side effects.
    public func shareFromCache<
        H0: Hashable, H1: Hashable, H2: Hashable, H3: Hashable, H4: Hashable, H5: Hashable,
        H6: Hashable, H7: Hashable
    >(
        _ cache: AUOWCache, strategy: any AUOWCacheStrategy, keys k0: H0, _ k1: H1, _ k2: H2, _ k3: H3,
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

    /// Shares the result of this unit of work from the given cache using the specified strategy and custom cache keys.
    ///
    /// Use this operator to share or de-duplicate expensive work based on custom, hashable cache keys.
    ///
    /// ## Example
    /// ```
    /// let cache = AUOWCache()
    /// let shared = DeferredTask { UUID() }
    ///     .shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation, keys: "user", 42, "session", 1, "extra", 99, "flag", true, 1000)
    /// async let a = shared.execute()
    /// async let b = shared.execute()
    /// let (val1, val2) = try await (a, b)
    /// // val1 and val2 are guaranteed to be identical (from cache)
    /// ```
    ///
    /// - Parameters:
    ///   - cache: The cache to share results from.
    ///   - strategy: The caching strategy.
    ///   - keys: Hashable key(s) to identify the cache entry.
    /// - Returns: An `AsynchronousUnitOfWork` that shares its results from cache.
    /// - Important: This operator should generally be placed at the end of an operator chain. Any operators applied after `shareFromCache` will not be shared and may result in duplicated work or side effects.
    public func shareFromCache<
        H0: Hashable, H1: Hashable, H2: Hashable, H3: Hashable, H4: Hashable, H5: Hashable,
        H6: Hashable, H7: Hashable, H8: Hashable
    >(
        _ cache: AUOWCache, strategy: any AUOWCacheStrategy, keys k0: H0, _ k1: H1, _ k2: H2, _ k3: H3,
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

    /// Shares the result of this unit of work from the given cache using the specified strategy and custom cache keys.
    ///
    /// Use this operator to share or de-duplicate expensive work based on custom, hashable cache keys.
    ///
    /// ## Example
    /// ```
    /// let cache = AUOWCache()
    /// let shared = DeferredTask { UUID() }
    ///     .shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation, keys: "user", 42, "session", 1, "extra", 99, "flag", true, 1000, false)
    /// async let a = shared.execute()
    /// async let b = shared.execute()
    /// let (val1, val2) = try await (a, b)
    /// // val1 and val2 are guaranteed to be identical (from cache)
    /// ```
    ///
    /// - Parameters:
    ///   - cache: The cache to share results from.
    ///   - strategy: The caching strategy.
    ///   - keys: Hashable key(s) to identify the cache entry.
    /// - Returns: An `AsynchronousUnitOfWork` that shares its results from cache.
    /// - Important: This operator should generally be placed at the end of an operator chain. Any operators applied after `shareFromCache` will not be shared and may result in duplicated work or side effects.
    public func shareFromCache<
        H0: Hashable, H1: Hashable, H2: Hashable, H3: Hashable, H4: Hashable, H5: Hashable,
        H6: Hashable, H7: Hashable, H8: Hashable, H9: Hashable
    >(
        _ cache: AUOWCache, strategy: any AUOWCacheStrategy, keys k0: H0, _ k1: H1, _ k2: H2, _ k3: H3,
        _ k4: H4, _ k5: H5, _ k6: H6, _ k7: H7, _ k8: H8, _ k9: H9
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
        hasher.combine(k9)
        return _shareFromCache(cache, strategy: strategy, hasher: &hasher)
    }
}

