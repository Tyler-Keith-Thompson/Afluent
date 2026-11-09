//
//  ShareFromCacheTests.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import AfluentTesting
import Atomics
import Clocks
import ConcurrencyExtras
import Foundation
import Testing

@testable import Afluent

struct ShareFromCacheTests {
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func sharingFromCacheWithNoKey() async throws {
        actor Test {
            var callCount = 0

            func increment() {
                callCount += 1
            }
        }
        let clock = TrackedTestClock()
        let d2Resolved = ManagedAtomic(false)
        let test = Test()
        let cache = AUOWCache()

        @Sendable func unitOfWork() -> some AsynchronousUnitOfWork<String> {
            DeferredTask {
                await test.increment()
                return UUID().uuidString
            }
            .delay(for: .milliseconds(10), clock: clock)
            .shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation)
        }

        let uow = unitOfWork()
        async let d1 = uow.execute()
        #expect(!cache.cache.isEmpty)
        async let d2 = DeferredTask {}
            .delay(for: .milliseconds(5), clock: clock)
            .flatMap {
                #expect(!cache.cache.isEmpty)
                let uow = unitOfWork()
                let key = try #require(cache.cache.keys.first)
                let o1 = try ObjectIdentifier(#require(cache.cache[key]))
                let o2 = try ObjectIdentifier(
                    #require(uow as? AnyAsynchronousUnitOfWork<String>).upstream as AnyObject)
                #expect(o1 == o2)
                d2Resolved.store(true, ordering: .sequentiallyConsistent)
                return uow
            }
            .execute()

        // d2 must pick up the cached work while d1 is still in flight.
        try await clock.advance(by: .milliseconds(5), whenSleeping: 2)
        try await wait(
            until: d2Resolved.load(ordering: .sequentiallyConsistent), timeout: .seconds(2))
        await clock.advance(by: .milliseconds(10))
        _ = try await d1
        _ = try await d2

        let callCount = await test.callCount
        #expect(callCount == 1)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func sharingFromCacheAfterCompletion() async throws {
        actor Test {
            var callCount = 0

            func increment() {
                callCount += 1
            }
        }
        let test = Test()
        let cache = AUOWCache()
        let clock = TrackedTestClock()
        let d2Resolved = ManagedAtomic(false)

        @Sendable func unitOfWork() -> some AsynchronousUnitOfWork<String> {
            DeferredTask {
                await test.increment()
                return UUID().uuidString
            }
            .delay(for: .milliseconds(10), clock: clock)
            .shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation)
        }

        let uow = unitOfWork()
        async let d1 = uow.execute()
        #expect(!cache.cache.isEmpty)
        async let d2 = DeferredTask {}
            .delay(for: .milliseconds(15), clock: clock)
            .flatMap {
                #expect(cache.cache.isEmpty)
                d2Resolved.store(true, ordering: .sequentiallyConsistent)
                return unitOfWork()
            }
            .execute()

        try await clock.advance(by: .milliseconds(11), whenSleeping: 2)
        _ = try await d1
        // d2 wakes at 15 and starts new work, whose own 10 ms delay must be registered before time moves on.
        await clock.advance(by: .milliseconds(4))
        try await wait(
            until: d2Resolved.load(ordering: .sequentiallyConsistent), timeout: .seconds(2))
        try await clock.advance(by: .milliseconds(10), whenSleeping: 1)
        _ = try await d2

        let callCount = await test.callCount
        #expect(callCount == 2)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func sharingFromCacheAfterError() async throws {
        actor Test {
            var callCount = 0

            func increment() {
                callCount += 1
            }
        }
        enum Err: Error { case e1 }
        let test = Test()
        let cache = AUOWCache()
        let clock = TrackedTestClock()

        @Sendable func unitOfWork() -> some AsynchronousUnitOfWork<String> {
            DeferredTask {
                await test.increment()
                throw Err.e1
            }
            .delay(for: .milliseconds(10), clock: clock)
            .shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation)
        }

        let uow = unitOfWork()
        async let d1 = uow.execute()
        #expect(!cache.cache.isEmpty)
        async let d2 = DeferredTask {}
            .delay(for: .milliseconds(15), clock: clock)
            .flatMap {
                #expect(cache.cache.isEmpty)
                return unitOfWork()
            }
            .execute()

        let err1: Error?
        let err2: Error?
        // The work throws before `delay` sleeps, so only d2's delay is ever on the clock.
        try await wait(until: clock.sleepingCount == 1, timeout: .seconds(2))
        do {
            await clock.advance(by: .milliseconds(11))
            _ = try await d1
            err1 = nil
        } catch {
            err1 = error
        }
        do {
            await clock.advance(by: .milliseconds(4))
            _ = try await d2
            err2 = nil
        } catch {
            err2 = error
        }

        #expect(err1 as? Err == Err.e1)
        #expect(err2 as? Err == Err.e1)

        let callCount = await test.callCount
        #expect(callCount == 2)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func sharingFromCacheWithKey() async throws {
        actor Test {
            var callCount = 0

            func increment() {
                callCount += 1
            }
        }
        let test = Test()
        let cache = AUOWCache()
        let clock = TrackedTestClock()
        let d2Resolved = ManagedAtomic(false)

        @Sendable func unitOfWork() -> some AsynchronousUnitOfWork<String> {
            DeferredTask {
                await test.increment()
                return UUID().uuidString
            }
            .delay(for: .milliseconds(10), clock: clock)
            .shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation, keys: 1)
        }

        let uow = unitOfWork()
        async let d1 = uow.execute()
        #expect(!cache.cache.isEmpty)
        async let d2 = DeferredTask {}
            .delay(for: .milliseconds(5), clock: clock)
            .flatMap {
                // Look up the cached work before signalling, so the test cannot let d1 finish and clear the
                // cache while d2 has yet to find it.
                let work = unitOfWork()
                d2Resolved.store(true, ordering: .sequentiallyConsistent)
                return work
            }
            .execute()

        try await clock.advance(by: .milliseconds(5), whenSleeping: 2)
        try await wait(
            until: d2Resolved.load(ordering: .sequentiallyConsistent), timeout: .seconds(2))
        await clock.advance(by: .milliseconds(6))
        _ = try await d1
        _ = try await d2

        let callCount = await test.callCount
        #expect(callCount == 1)
    }

    @Test func sharingFromCacheCancelAndRestartCancelsInFlightRequest() async throws {
        let cache = AUOWCache()
        let clock = TrackedTestClock()

        @Sendable func unitOfWork() -> some AsynchronousUnitOfWork<String> {
            DeferredTask {
                UUID().uuidString
            }
            .delay(for: .milliseconds(10), clock: clock)
            .shareFromCache(cache, strategy: .cancelAndRestart)
        }

        // The first request must be in flight (sleeping) before the second one replaces it.
        let first = unitOfWork()
        async let _r1 = Result { try await first.execute() }
        try await wait(until: clock.sleepingCount == 1, timeout: .seconds(2))
        let second = unitOfWork()
        async let _r2 = Result { try await second.execute() }

        let r1 = await _r1
        #expect(throws: CancellationError.self) {
            try r1.get()
        }
        try await clock.advance(by: .milliseconds(11), whenSleeping: 1)
        _ = try await _r2.get()
    }

    @Test func sharingFromCacheCancelAndRestartAfterCompletion() async throws {
        let cache = AUOWCache()
        let clock = TrackedTestClock()

        @Sendable func unitOfWork() -> some AsynchronousUnitOfWork<String> {
            DeferredTask {
                UUID().uuidString
            }
            .delay(for: .milliseconds(10), clock: clock)
            .shareFromCache(cache, strategy: .cancelAndRestart)
        }

        let first = unitOfWork()
        async let _r1 = Result { try await first.execute() }
        try await clock.advance(by: .milliseconds(11), whenSleeping: 1)
        let r1 = await _r1

        let second = unitOfWork()
        async let _r2 = Result { try await second.execute() }
        try await clock.advance(by: .milliseconds(11), whenSleeping: 1)
        let r2 = await _r2

        _ = try r1.get()
        _ = try r2.get()
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(
        "Releasing the cache while its shared work is running cancels the work",
        .timeLimit(.minutes(1)))
    func releasingTheCacheCancelsRunningSharedWork() async throws {
        let (started, startedContinuation) = AsyncStream<Void>.makeStream()
        var cache: AUOWCache? = AUOWCache()
        let work = DeferredTask {
            startedContinuation.yield()
            let (pending, keepOpen) = AsyncStream<Void>.makeStream()
            for await _ in pending {}
            keepOpen.finish()
            try Task.checkCancellation()
        }
        .shareFromCache(try #require(cache), strategy: .cacheUntilCompletionOrCancellation)
        let execution = Task { try await work.execute() }
        for await _ in started { break }

        cache = nil

        let result = await execution.result
        #expect(throws: CancellationError.self) { try result.get() }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(
        "Releasing the cache cancels its work after the cache's lock is released",
        .timeLimit(.minutes(1)))
    func releasingTheCacheCancelsOutsideItsLock() async throws {
        // A unit of work whose cancel runs its cancellation handler inline, on the thread releasing the cache.
        final class Work: AsynchronousUnitOfWork {
            let state = TaskState<Void>()
            let body: @Sendable () async throws -> Void
            init(_ body: @escaping @Sendable () async throws -> Void) { self.body = body }
            func _operation() async throws -> AsynchronousOperation<Void> {
                AsynchronousOperation(operation: body)
            }
        }
        let (started, startedContinuation) = AsyncStream<Void>.makeStream()
        let lockWasFree = LockIsolated<Bool?>(nil)
        var cache: AUOWCache? = AUOWCache()
        let cacheLock = try #require(cache).lock
        @Sendable func recordWhetherTheCacheLockIsFree() {
            // Another thread takes the lock, so a lock the releasing thread still holds shows up as a timeout
            // rather than as recursive re-entry.
            let acquired = DispatchSemaphore(value: 0)
            Thread {
                cacheLock.lock()
                cacheLock.unlock()
                acquired.signal()
            }.start()
            lockWasFree.setValue(acquired.wait(timeout: .now() + .seconds(10)) == .success)
        }
        let work = Work {
            let (pending, keepOpen) = AsyncStream<Void>.makeStream()
            await withTaskCancellationHandler {
                startedContinuation.yield()
                for await _ in pending {}
            } onCancel: {
                recordWhetherTheCacheLockIsFree()
                keepOpen.finish()
            }
        }
        _ = try #require(cache).create(unitOfWork: work, keyedBy: 0)
        work.run()
        for await _ in started { break }

        cache = nil

        #expect(lockWasFree.value == true)
    }
}
