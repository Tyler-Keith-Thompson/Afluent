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
    public func shareFromCache<each H: Hashable>(
        _ cache: AUOWCache, strategy: AUOWCache.Strategy, keys: repeat each H
    ) -> some AsynchronousUnitOfWork<Success> {
        var hasher = Hasher()
        repeat hasher.combine(each keys)
        return _shareFromCache(cache, strategy: strategy, hasher: &hasher)
    }
}
