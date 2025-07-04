//
//  ShareFromCacheSequence.swift
//  Afluent
//
//  Created by Tyler Thompson on 10/19/24.
//

import Foundation

extension AsyncSequence where Self: Sendable, Element: Sendable {
    func _shareFromCache(
        _ cache: AsyncSequenceCache, strategy: AsyncSequenceCache.Strategy, hasher: inout Hasher,
        fileId: String = "",
        function: String = "", line: UInt = 0, column: UInt = 0
    ) -> AsyncBroadcastSequence<AsyncSequences.HandleEvents<Self>> {
        hasher.combine(fileId)
        hasher.combine(function)
        hasher.combine(line)
        hasher.combine(column)
        let key = hasher.finalize()
        switch strategy {
            case .cacheUntilCompletionOrCancellation:
                return cache.retrieveOrCreate(
                    unitOfWork: handleEvents(
                        receiveError: { [weak cache] _ in
                            cache?.clearAsynchronousUnitOfWork(withKey: key)
                        },
                        receiveComplete: { [weak cache] in
                            cache?.clearAsynchronousUnitOfWork(withKey: key)
                        },
                        receiveCancel: { [weak cache] in
                            cache?.clearAsynchronousUnitOfWork(withKey: key)
                        }
                    ).share(),
                    keyedBy: key)
        }
    }

    /// This operator enables sharing and caching of results from an async sequence
    /// based on a specified caching strategy and the context in which it is called
    /// (file, function, line, column). The cache keys uniquely identify the shared sequence 
    /// in the cache using these call-site identifiers.
    ///
    /// ## Example
    /// ```swift
    /// let cache = AsyncSequenceCache()
    /// let sequence = fetchNetworkData() // Some async sequence fetching network data
    /// let sharedSequence = sequence.shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation)
    ///
    /// Task {
    ///     for await data in sharedSequence {
    ///         print("Received data: \(data)")
    ///     }
    /// }
    /// ```
    ///
    /// In this example, calls from the same file, function, line, and column will share and cache
    /// the results of `fetchNetworkData()`, preventing redundant network requests within the same call site.
    ///
    /// - Parameters:
    ///   - cache: The cache from which to share data.
    ///   - strategy: The caching strategy to use.
    ///   - fileId: The ID of the file where this function is called. Defaults to `#fileID`.
    ///   - function: The name of the calling function. Defaults to `#function`.
    ///   - line: The line number where this function is called. Defaults to `#line`.
    ///   - column: The column where this function is called. Defaults to `#column`.
    /// - Returns: An asynchronous broadcast sequence that shares the underlying sequence's values according to the cache and strategy.
    /// - Important: This operator should generally be placed at the end of an operator chain. Any operators applied after `shareFromCache` will not be shared and may result in duplicated work or side effects.
    public func shareFromCache(
        _ cache: AsyncSequenceCache, strategy: AsyncSequenceCache.Strategy,
        fileId: String = #fileID,
        function: String = #function, line: UInt = #line, column: UInt = #column
    ) -> AsyncBroadcastSequence<AsyncSequences.HandleEvents<Self>> {
        var hasher = Hasher()
        return _shareFromCache(
            cache, strategy: strategy, hasher: &hasher, fileId: fileId, function: function,
            line: line, column: column)
    }

    /// This operator enables sharing and caching of results from an async sequence
    /// based on a specified caching strategy and a single hashable cache key.
    /// The hashable key uniquely identifies the shared sequence in the cache.
    ///
    /// ## Example
    /// ```swift
    /// struct UserID: Hashable { let id: Int }
    ///
    /// let cache = AsyncSequenceCache()
    /// let userSequence = fetchUserData(userId: 42) // Async sequence fetching user data
    /// let sharedUserSequence = userSequence.shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation, keys: UserID(id: 42))
    ///
    /// Task {
    ///     for await user in sharedUserSequence {
    ///         print("User data: \(user)")
    ///     }
    /// }
    /// ```
    ///
    /// Here, the cache key `UserID(id: 42)` uniquely identifies the cached shared sequence,
    /// ensuring that requests for the same user share the underlying async sequence.
    ///
    /// - Parameters:
    ///   - cache: The cache from which to share data.
    ///   - strategy: The caching strategy to use.
    ///   - keys k0: A hashable key used to uniquely identify the shared sequence in the cache.
    /// - Returns: An asynchronous broadcast sequence that shares the underlying sequence's values according to the cache and strategy.
    /// - Important: This operator should generally be placed at the end of an operator chain. Any operators applied after `shareFromCache` will not be shared and may result in duplicated work or side effects.
    public func shareFromCache<H0: Hashable>(
        _ cache: AsyncSequenceCache, strategy: AsyncSequenceCache.Strategy, keys k0: H0
    ) -> AsyncBroadcastSequence<AsyncSequences.HandleEvents<Self>> {
        var hasher = Hasher()
        hasher.combine(k0)
        return _shareFromCache(cache, strategy: strategy, hasher: &hasher)
    }

    /// This operator enables sharing and caching of results from an async sequence
    /// based on a specified caching strategy and two hashable cache keys.
    /// The combined hashable keys uniquely identify the shared sequence in the cache.
    ///
    /// ## Example
    /// ```swift
    /// let cache = AsyncSequenceCache()
    /// let sequence = expensiveComputation(param1: "abc", param2: 123)
    /// let sharedSequence = sequence.shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation, keys: "abc", 123)
    ///
    /// Task {
    ///     for await result in sharedSequence {
    ///         print("Computation result: \(result)")
    ///     }
    /// }
    /// ```
    ///
    /// The keys `"abc"` and `123` combined serve as a unique cache key, allowing sharing
    /// and caching of results for the specific combination of parameters.
    ///
    /// - Parameters:
    ///   - cache: The cache from which to share data.
    ///   - strategy: The caching strategy to use.
    ///   - keys k0: The first hashable key.
    ///   - k1: The second hashable key.
    /// - Returns: An asynchronous broadcast sequence that shares the underlying sequence's values according to the cache and strategy.
    /// - Important: This operator should generally be placed at the end of an operator chain. Any operators applied after `shareFromCache` will not be shared and may result in duplicated work or side effects.
    public func shareFromCache<H0: Hashable, H1: Hashable>(
        _ cache: AsyncSequenceCache, strategy: AsyncSequenceCache.Strategy, keys k0: H0, _ k1: H1
    ) -> AsyncBroadcastSequence<AsyncSequences.HandleEvents<Self>> {
        var hasher = Hasher()
        hasher.combine(k0)
        hasher.combine(k1)
        return _shareFromCache(cache, strategy: strategy, hasher: &hasher)
    }

    /// This operator enables sharing and caching of results from an async sequence
    /// based on a specified caching strategy and three hashable cache keys.
    /// The combined hashable keys uniquely identify the shared sequence in the cache.
    ///
    /// ## Example
    /// ```swift
    /// let cache = AsyncSequenceCache()
    /// let sequence = fetchData(category: "books", page: 2, filter: "bestsellers")
    /// let sharedSequence = sequence.shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation, keys: "books", 2, "bestsellers")
    ///
    /// Task {
    ///     for await data in sharedSequence {
    ///         print("Fetched data: \(data)")
    ///     }
    /// }
    /// ```
    ///
    /// The combination of keys `"books"`, `2`, and `"bestsellers"` uniquely identifies the cache entry.
    ///
    /// - Parameters:
    ///   - cache: The cache from which to share data.
    ///   - strategy: The caching strategy to use.
    ///   - keys k0: The first hashable key.
    ///   - k1: The second hashable key.
    ///   - k2: The third hashable key.
    /// - Returns: An asynchronous broadcast sequence that shares the underlying sequence's values according to the cache and strategy.
    /// - Important: This operator should generally be placed at the end of an operator chain. Any operators applied after `shareFromCache` will not be shared and may result in duplicated work or side effects.
    public func shareFromCache<H0: Hashable, H1: Hashable, H2: Hashable>(
        _ cache: AsyncSequenceCache, strategy: AsyncSequenceCache.Strategy, keys k0: H0, _ k1: H1,
        _ k2: H2
    ) -> AsyncBroadcastSequence<AsyncSequences.HandleEvents<Self>> {
        var hasher = Hasher()
        hasher.combine(k0)
        hasher.combine(k1)
        hasher.combine(k2)
        return _shareFromCache(cache, strategy: strategy, hasher: &hasher)
    }

    /// This operator enables sharing and caching of results from an async sequence
    /// based on a specified caching strategy and four hashable cache keys.
    /// The combined hashable keys uniquely identify the shared sequence in the cache.
    ///
    /// ## Example
    /// ```swift
    /// let cache = AsyncSequenceCache()
    /// let sequence = fetchEvents(year: 2025, month: 7, day: 4, location: "NYC")
    /// let sharedSequence = sequence.shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation, keys: 2025, 7, 4, "NYC")
    ///
    /// Task {
    ///     for await event in sharedSequence {
    ///         print("Event: \(event)")
    ///     }
    /// }
    /// ```
    ///
    /// These keys combined uniquely identify the cached shared sequence.
    ///
    /// - Parameters:
    ///   - cache: The cache from which to share data.
    ///   - strategy: The caching strategy to use.
    ///   - keys k0: The first hashable key.
    ///   - k1: The second hashable key.
    ///   - k2: The third hashable key.
    ///   - k3: The fourth hashable key.
    /// - Returns: An asynchronous broadcast sequence that shares the underlying sequence's values according to the cache and strategy.
    /// - Important: This operator should generally be placed at the end of an operator chain. Any operators applied after `shareFromCache` will not be shared and may result in duplicated work or side effects.
    public func shareFromCache<H0: Hashable, H1: Hashable, H2: Hashable, H3: Hashable>(
        _ cache: AsyncSequenceCache, strategy: AsyncSequenceCache.Strategy, keys k0: H0, _ k1: H1,
        _ k2: H2, _ k3: H3
    ) -> AsyncBroadcastSequence<AsyncSequences.HandleEvents<Self>> {
        var hasher = Hasher()
        hasher.combine(k0)
        hasher.combine(k1)
        hasher.combine(k2)
        hasher.combine(k3)
        return _shareFromCache(cache, strategy: strategy, hasher: &hasher)
    }

    /// This operator enables sharing and caching of results from an async sequence
    /// based on a specified caching strategy and five hashable cache keys.
    /// The combined hashable keys uniquely identify the shared sequence in the cache.
    ///
    /// ## Example
    /// ```swift
    /// let cache = AsyncSequenceCache()
    /// let sequence = fetchWeatherData(year: 2025, month: 7, day: 4, city: "Seattle", metric: true)
    /// let sharedSequence = sequence.shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation, keys: 2025, 7, 4, "Seattle", true)
    ///
    /// Task {
    ///     for await weather in sharedSequence {
    ///         print("Weather data: \(weather)")
    ///     }
    /// }
    /// ```
    ///
    /// The keys specify the unique cache entry for this query.
    ///
    /// - Parameters:
    ///   - cache: The cache from which to share data.
    ///   - strategy: The caching strategy to use.
    ///   - keys k0: The first hashable key.
    ///   - k1: The second hashable key.
    ///   - k2: The third hashable key.
    ///   - k3: The fourth hashable key.
    ///   - k4: The fifth hashable key.
    /// - Returns: An asynchronous broadcast sequence that shares the underlying sequence's values according to the cache and strategy.
    /// - Important: This operator should generally be placed at the end of an operator chain. Any operators applied after `shareFromCache` will not be shared and may result in duplicated work or side effects.
    public func shareFromCache<
        H0: Hashable, H1: Hashable, H2: Hashable, H3: Hashable, H4: Hashable
    >(
        _ cache: AsyncSequenceCache, strategy: AsyncSequenceCache.Strategy, keys k0: H0, _ k1: H1,
        _ k2: H2, _ k3: H3,
        _ k4: H4
    ) -> AsyncBroadcastSequence<AsyncSequences.HandleEvents<Self>> {
        var hasher = Hasher()
        hasher.combine(k0)
        hasher.combine(k1)
        hasher.combine(k2)
        hasher.combine(k3)
        hasher.combine(k4)
        return _shareFromCache(cache, strategy: strategy, hasher: &hasher)
    }

    /// This operator enables sharing and caching of results from an async sequence
    /// based on a specified caching strategy and six hashable cache keys.
    /// The combined hashable keys uniquely identify the shared sequence in the cache.
    ///
    /// ## Example
    /// ```swift
    /// let cache = AsyncSequenceCache()
    /// let sequence = fetchMetrics(region: "US", year: 2025, month: 7, day: 4, category: "sales", subcategory: "online")
    /// let sharedSequence = sequence.shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation, keys: "US", 2025, 7, 4, "sales", "online")
    ///
    /// Task {
    ///     for await metric in sharedSequence {
    ///         print("Metric: \(metric)")
    ///     }
    /// }
    /// ```
    ///
    /// These six keys combined provide a unique cache key.
    ///
    /// - Parameters:
    ///   - cache: The cache from which to share data.
    ///   - strategy: The caching strategy to use.
    ///   - keys k0: The first hashable key.
    ///   - k1: The second hashable key.
    ///   - k2: The third hashable key.
    ///   - k3: The fourth hashable key.
    ///   - k4: The fifth hashable key.
    ///   - k5: The sixth hashable key.
    /// - Returns: An asynchronous broadcast sequence that shares the underlying sequence's values according to the cache and strategy.
    /// - Important: This operator should generally be placed at the end of an operator chain. Any operators applied after `shareFromCache` will not be shared and may result in duplicated work or side effects.
    public func shareFromCache<
        H0: Hashable, H1: Hashable, H2: Hashable, H3: Hashable, H4: Hashable, H5: Hashable
    >(
        _ cache: AsyncSequenceCache, strategy: AsyncSequenceCache.Strategy, keys k0: H0, _ k1: H1,
        _ k2: H2, _ k3: H3,
        _ k4: H4, _ k5: H5
    ) -> AsyncBroadcastSequence<AsyncSequences.HandleEvents<Self>> {
        var hasher = Hasher()
        hasher.combine(k0)
        hasher.combine(k1)
        hasher.combine(k2)
        hasher.combine(k3)
        hasher.combine(k4)
        hasher.combine(k5)
        return _shareFromCache(cache, strategy: strategy, hasher: &hasher)
    }

    /// This operator enables sharing and caching of results from an async sequence
    /// based on a specified caching strategy and seven hashable cache keys.
    /// The combined hashable keys uniquely identify the shared sequence in the cache.
    ///
    /// ## Example
    /// ```swift
    /// let cache = AsyncSequenceCache()
    /// let sequence = fetchReportData(region: "EU", year: 2025, month: 7, day: 4, reportType: "summary", version: 2, language: "en")
    /// let sharedSequence = sequence.shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation, keys: "EU", 2025, 7, 4, "summary", 2, "en")
    ///
    /// Task {
    ///     for await report in sharedSequence {
    ///         print("Report: \(report)")
    ///     }
    /// }
    /// ```
    ///
    /// These seven keys combined provide a unique cache key.
    ///
    /// - Parameters:
    ///   - cache: The cache from which to share data.
    ///   - strategy: The caching strategy to use.
    ///   - keys k0: The first hashable key.
    ///   - k1: The second hashable key.
    ///   - k2: The third hashable key.
    ///   - k3: The fourth hashable key.
    ///   - k4: The fifth hashable key.
    ///   - k5: The sixth hashable key.
    ///   - k6: The seventh hashable key.
    /// - Returns: An asynchronous broadcast sequence that shares the underlying sequence's values according to the cache and strategy.
    /// - Important: This operator should generally be placed at the end of an operator chain. Any operators applied after `shareFromCache` will not be shared and may result in duplicated work or side effects.
    public func shareFromCache<
        H0: Hashable, H1: Hashable, H2: Hashable, H3: Hashable, H4: Hashable, H5: Hashable,
        H6: Hashable
    >(
        _ cache: AsyncSequenceCache, strategy: AsyncSequenceCache.Strategy, keys k0: H0, _ k1: H1,
        _ k2: H2, _ k3: H3,
        _ k4: H4, _ k5: H5, _ k6: H6
    ) -> AsyncBroadcastSequence<AsyncSequences.HandleEvents<Self>> {
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

    /// This operator enables sharing and caching of results from an async sequence
    /// based on a specified caching strategy and eight hashable cache keys.
    /// The combined hashable keys uniquely identify the shared sequence in the cache.
    ///
    /// ## Example
    /// ```swift
    /// let cache = AsyncSequenceCache()
    /// let sequence = fetchDataSet(a: 1, b: 2, c: 3, d: 4, e: 5, f: 6, g: 7, h: 8)
    /// let sharedSequence = sequence.shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation, keys: 1, 2, 3, 4, 5, 6, 7, 8)
    ///
    /// Task {
    ///     for await item in sharedSequence {
    ///         print("Item: \(item)")
    ///     }
    /// }
    /// ```
    ///
    /// These eight keys combined provide a unique cache key.
    ///
    /// - Parameters:
    ///   - cache: The cache from which to share data.
    ///   - strategy: The caching strategy to use.
    ///   - keys k0: The first hashable key.
    ///   - k1: The second hashable key.
    ///   - k2: The third hashable key.
    ///   - k3: The fourth hashable key.
    ///   - k4: The fifth hashable key.
    ///   - k5: The sixth hashable key.
    ///   - k6: The seventh hashable key.
    ///   - k7: The eighth hashable key.
    /// - Returns: An asynchronous broadcast sequence that shares the underlying sequence's values according to the cache and strategy.
    /// - Important: This operator should generally be placed at the end of an operator chain. Any operators applied after `shareFromCache` will not be shared and may result in duplicated work or side effects.
    public func shareFromCache<
        H0: Hashable, H1: Hashable, H2: Hashable, H3: Hashable, H4: Hashable, H5: Hashable,
        H6: Hashable, H7: Hashable
    >(
        _ cache: AsyncSequenceCache, strategy: AsyncSequenceCache.Strategy, keys k0: H0, _ k1: H1,
        _ k2: H2, _ k3: H3,
        _ k4: H4, _ k5: H5, _ k6: H6, _ k7: H7
    ) -> AsyncBroadcastSequence<AsyncSequences.HandleEvents<Self>> {
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

    /// This operator enables sharing and caching of results from an async sequence
    /// based on a specified caching strategy and nine hashable cache keys.
    /// The combined hashable keys uniquely identify the shared sequence in the cache.
    ///
    /// ## Example
    /// ```swift
    /// let cache = AsyncSequenceCache()
    /// let sequence = fetchData(a: 1, b: 2, c: 3, d: 4, e: 5, f: 6, g: 7, h: 8, i: 9)
    /// let sharedSequence = sequence.shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation, keys: 1, 2, 3, 4, 5, 6, 7, 8, 9)
    ///
    /// Task {
    ///     for await item in sharedSequence {
    ///         print("Item: \(item)")
    ///     }
    /// }
    /// ```
    ///
    /// These nine keys combined provide a unique cache key.
    ///
    /// - Parameters:
    ///   - cache: The cache from which to share data.
    ///   - strategy: The caching strategy to use.
    ///   - keys k0: The first hashable key.
    ///   - k1: The second hashable key.
    ///   - k2: The third hashable key.
    ///   - k3: The fourth hashable key.
    ///   - k4: The fifth hashable key.
    ///   - k5: The sixth hashable key.
    ///   - k6: The seventh hashable key.
    ///   - k7: The eighth hashable key.
    ///   - k8: The ninth hashable key.
    /// - Returns: An asynchronous broadcast sequence that shares the underlying sequence's values according to the cache and strategy.
    /// - Important: This operator should generally be placed at the end of an operator chain. Any operators applied after `shareFromCache` will not be shared and may result in duplicated work or side effects.
    public func shareFromCache<
        H0: Hashable, H1: Hashable, H2: Hashable, H3: Hashable, H4: Hashable, H5: Hashable,
        H6: Hashable, H7: Hashable, H8: Hashable
    >(
        _ cache: AsyncSequenceCache, strategy: AsyncSequenceCache.Strategy, keys k0: H0, _ k1: H1,
        _ k2: H2, _ k3: H3,
        _ k4: H4, _ k5: H5, _ k6: H6, _ k7: H7, _ k8: H8
    ) -> AsyncBroadcastSequence<AsyncSequences.HandleEvents<Self>> {
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

    /// This operator enables sharing and caching of results from an async sequence
    /// based on a specified caching strategy and ten hashable cache keys.
    /// The combined hashable keys uniquely identify the shared sequence in the cache.
    ///
    /// ## Example
    /// ```swift
    /// let cache = AsyncSequenceCache()
    /// let sequence = fetchData(a: 1, b: 2, c: 3, d: 4, e: 5, f: 6, g: 7, h: 8, i: 9, j: 10)
    /// let sharedSequence = sequence.shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation, keys: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
    ///
    /// Task {
    ///     for await item in sharedSequence {
    ///         print("Item: \(item)")
    ///     }
    /// }
    /// ```
    ///
    /// These ten keys combined provide a unique cache key.
    ///
    /// - Parameters:
    ///   - cache: The cache from which to share data.
    ///   - strategy: The caching strategy to use.
    ///   - keys k0: The first hashable key.
    ///   - k1: The second hashable key.
    ///   - k2: The third hashable key.
    ///   - k3: The fourth hashable key.
    ///   - k4: The fifth hashable key.
    ///   - k5: The sixth hashable key.
    ///   - k6: The seventh hashable key.
    ///   - k7: The eighth hashable key.
    ///   - k8: The ninth hashable key.
    ///   - 🐶: The tenth hashable key.
    /// - Returns: An asynchronous broadcast sequence that shares the underlying sequence's values according to the cache and strategy.
    /// - Important: This operator should generally be placed at the end of an operator chain. Any operators applied after `shareFromCache` will not be shared and may result in duplicated work or side effects.
    public func shareFromCache<
        H0: Hashable, H1: Hashable, H2: Hashable, H3: Hashable, H4: Hashable, H5: Hashable,
        H6: Hashable, H7: Hashable, H8: Hashable, H9: Hashable
    >(
        _ cache: AsyncSequenceCache, strategy: AsyncSequenceCache.Strategy, keys k0: H0, _ k1: H1,
        _ k2: H2, _ k3: H3,
        _ k4: H4, _ k5: H5, _ k6: H6, _ k7: H7, _ k8: H8, _ 🐶: H9
    ) -> AsyncBroadcastSequence<AsyncSequences.HandleEvents<Self>> {
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
