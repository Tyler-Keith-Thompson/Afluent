//
//  CacheReleaseTests.swift
//  Afluent
//

import Testing

@testable import Afluent

/// Each cached value's `deinit` takes the cache's lock, so a value released inside the lock would trap or hang.
struct CacheReleaseTests {
    @Test(
        "Replacing a unit of work with create releases the old one outside the cache's lock",
        .timeLimit(.minutes(1)))
    func createReleasesTheReplacedValueOutsideTheLock() {
        final class ReadsCacheOnDeinit: AsynchronousUnitOfWork {
            let state = TaskState<Int>()
            weak let cache: AUOWCache?
            init(_ cache: AUOWCache) { self.cache = cache }
            func _operation() async throws -> AsynchronousOperation<Int> { AsynchronousOperation { 1 } }
            deinit { _ = cache?.retrieve(keyedBy: 0) }
        }
        let cache = AUOWCache()
        let key = 1
        _ = cache.create(unitOfWork: ReadsCacheOnDeinit(cache), keyedBy: key)
        _ = cache.create(unitOfWork: ReadsCacheOnDeinit(cache), keyedBy: key)
        let cached = cache.retrieve(keyedBy: key)
        #expect(cached != nil)
    }

    @Test(
        "Replacing a unit of work of another type with retrieveOrCreate releases the old one outside the cache's lock",
        .timeLimit(.minutes(1)))
    func retrieveOrCreateReleasesAMismatchedValueOutsideTheLock() {
        final class ReadsCacheOnDeinit: AsynchronousUnitOfWork {
            let state = TaskState<Int>()
            weak let cache: AUOWCache?
            init(_ cache: AUOWCache) { self.cache = cache }
            func _operation() async throws -> AsynchronousOperation<Int> { AsynchronousOperation { 1 } }
            deinit { _ = cache?.retrieve(keyedBy: 0) }
        }
        final class Replacement: AsynchronousUnitOfWork {
            let state = TaskState<String>()
            func _operation() async throws -> AsynchronousOperation<String> { AsynchronousOperation { "" } }
        }
        let cache = AUOWCache()
        let key = 1
        _ = cache.create(unitOfWork: ReadsCacheOnDeinit(cache), keyedBy: key)
        let replacement = Replacement()
        let returned = cache.retrieveOrCreate(unitOfWork: replacement, keyedBy: key)
        #expect(returned === replacement)
    }

    @Test(
        "Clearing a unit of work releases it outside the cache's lock", .timeLimit(.minutes(1)))
    func clearReleasesTheValueOutsideTheLock() {
        final class ReadsCacheOnDeinit: AsynchronousUnitOfWork {
            let state = TaskState<Int>()
            weak let cache: AUOWCache?
            init(_ cache: AUOWCache) { self.cache = cache }
            func _operation() async throws -> AsynchronousOperation<Int> { AsynchronousOperation { 1 } }
            deinit { _ = cache?.retrieve(keyedBy: 0) }
        }
        let cache = AUOWCache()
        let key = 1
        _ = cache.create(unitOfWork: ReadsCacheOnDeinit(cache), keyedBy: key)
        cache.clearAsynchronousUnitOfWork(withKey: key)
        let cached = cache.retrieve(keyedBy: key)
        #expect(cached == nil)
    }

    @Test(
        "Replacing a sequence of another type in an AsyncSequenceCache releases the old one outside the cache's lock",
        .timeLimit(.minutes(1)))
    func sequenceCacheReleasesAMismatchedValueOutsideTheLock() {
        final class ClearsCacheOnDeinit: AsyncSequence, Sendable {
            typealias Element = Int
            weak let cache: AsyncSequenceCache?
            init(_ cache: AsyncSequenceCache) { self.cache = cache }
            func makeAsyncIterator() -> AsyncStream<Int>.Iterator { AsyncStream<Int> { $0.finish() }.makeAsyncIterator() }
            deinit { cache?.clearAsynchronousUnitOfWork(withKey: 0) }
        }
        let cache = AsyncSequenceCache()
        let key = 1
        _ = cache.retrieveOrCreate(unitOfWork: ClearsCacheOnDeinit(cache), keyedBy: key)
        let replacement = Just(1)
        _ = cache.retrieveOrCreate(unitOfWork: replacement, keyedBy: key)
        let cachedCount = cache.cache.count
        #expect(cachedCount == 1)
    }

    @Test(
        "Clearing a sequence in an AsyncSequenceCache releases it outside the cache's lock",
        .timeLimit(.minutes(1)))
    func sequenceCacheClearReleasesTheValueOutsideTheLock() {
        final class ClearsCacheOnDeinit: AsyncSequence, Sendable {
            typealias Element = Int
            weak let cache: AsyncSequenceCache?
            init(_ cache: AsyncSequenceCache) { self.cache = cache }
            func makeAsyncIterator() -> AsyncStream<Int>.Iterator { AsyncStream<Int> { $0.finish() }.makeAsyncIterator() }
            deinit { cache?.clearAsynchronousUnitOfWork(withKey: 0) }
        }
        let cache = AsyncSequenceCache()
        let key = 1
        _ = cache.retrieveOrCreate(unitOfWork: ClearsCacheOnDeinit(cache), keyedBy: key)
        cache.clearAsynchronousUnitOfWork(withKey: key)
        let cachedIsEmpty = cache.cache.isEmpty
        #expect(cachedIsEmpty)
    }
}
