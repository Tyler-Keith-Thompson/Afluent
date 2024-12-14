//
//  ShareFromCacheTests.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Clocks
import ConcurrencyExtras
import Foundation
import Testing

@testable import Afluent

struct ShareFromCacheTests {
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func sharingFromCacheWithNoKey() async throws {
        try await withMainSerialExecutor {
            actor Test {
                var callCount = 0

                func increment() {
                    callCount += 1
                }
            }
            let clock = TestClock()
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
                    let o2 = try ObjectIdentifier(#require(uow as AnyObject))
                    #expect(o1 == o2)
                    return uow
                }
                .execute()

            await clock.advance(by: .milliseconds(15))
            let d1Value = try await d1
            let d2Value = try await d2
            #expect(d1Value == d2Value)

            let callCount = await test.callCount
            #expect(callCount == 1)
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func sharingFromCacheAfterCompletion() async throws {
        try await withMainSerialExecutor {
            actor Test {
                var callCount = 0

                func increment() {
                    callCount += 1
                }
            }
            let test = Test()
            let cache = AUOWCache()
            let clock = TestClock()

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
                    return unitOfWork()
                }
                .execute()

            await clock.advance(by: .milliseconds(11))
            let d1Value = try await d1
            await clock.advance(by: .milliseconds(16))
            let d2Value = try await d2
            #expect(d1Value != d2Value)

            let callCount = await test.callCount
            #expect(callCount == 2)
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func sharingFromCacheAfterError() async throws {
        await withMainSerialExecutor {
            actor Test {
                var callCount = 0

                func increment() {
                    callCount += 1
                }
            }
            enum Err: Error { case e1 }
            let test = Test()
            let cache = AUOWCache()
            let clock = TestClock()

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
            do {
                await clock.advance(by: .milliseconds(11))
                _ = try await d1
                err1 = nil
            } catch {
                err1 = error
            }
            do {
                await clock.advance(by: .milliseconds(16))
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
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func sharingFromCacheWithKey() async throws {
        try await withMainSerialExecutor {
            actor Test {
                var callCount = 0

                func reset() {
                    callCount = 0
                }

                func increment() {
                    callCount += 1
                }
            }
            let test = Test()
            let cache = AUOWCache()
            let clock = TestClock()

            @Sendable func unitOfWork<H: Hashable>(key: H) -> some AsynchronousUnitOfWork<String> {
                DeferredTask {
                    await test.increment()
                    return UUID().uuidString
                }
                .delay(for: .milliseconds(10), clock: clock)
                .shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation, keys: key)
            }

            try await {
                let uow = unitOfWork(key: 1)
                async let d1 = uow.execute()
                #expect(!cache.cache.isEmpty)
                async let d2 = DeferredTask {}
                    .delay(for: .milliseconds(5), clock: clock)
                    .flatMap { unitOfWork(key: 1) }
                    .execute()

                await clock.advance(by: .milliseconds(11))
                let d1Value = try await d1
                let d2Value = try await d2
                #expect(d1Value == d2Value)

                let callCount = await test.callCount
                #expect(callCount == 1)
            }()

            await test.reset()

            try await {
                let uow = unitOfWork(key: 1)
                async let d1 = uow.execute()
                #expect(!cache.cache.isEmpty)
                async let d2 = DeferredTask {}
                    .delay(for: .milliseconds(5), clock: clock)
                    .flatMap { unitOfWork(key: 2) }
                    .execute()

                await clock.advance(by: .milliseconds(21))
                let d1Value = try await d1
                let d2Value = try await d2
                #expect(d1Value != d2Value)

                let callCount = await test.callCount
                #expect(callCount == 2)
            }()
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func sharingFromCacheWithManyKeys() async throws {
        try await withMainSerialExecutor {
            actor Test {
                var callCount = 0

                func reset() {
                    callCount = 0
                }

                func increment() {
                    callCount += 1
                }
            }
            let test = Test()
            let cache = AUOWCache()
            let clock = TestClock()

            @Sendable func unitOfWork<H: Hashable>(key: H) -> some AsynchronousUnitOfWork<String> {
                DeferredTask {
                    await test.increment()
                    return UUID().uuidString
                }
                .delay(for: .milliseconds(10), clock: clock)
                .shareFromCache(
                    cache, strategy: .cacheUntilCompletionOrCancellation, keys: key, "a", 0.0, true)
            }

            try await {
                let uow = unitOfWork(key: true)
                async let d1 = uow.execute()
                #expect(!cache.cache.isEmpty)
                async let d2 = DeferredTask {}
                    .delay(for: .milliseconds(5), clock: clock)
                    .flatMap { unitOfWork(key: true) }
                    .execute()

                await clock.advance(by: .milliseconds(11))
                let d1Value = try await d1
                let d2Value = try await d2
                #expect(d1Value == d2Value)

                let callCount = await test.callCount
                #expect(callCount == 1)
            }()

            await test.reset()

            try await {
                let uow = unitOfWork(key: 1)
                async let d1 = uow.execute()
                #expect(!cache.cache.isEmpty)
                async let d2 = DeferredTask {}
                    .delay(for: .milliseconds(5), clock: clock)
                    .flatMap { unitOfWork(key: 2) }
                    .execute()

                await clock.advance(by: .milliseconds(21))
                let d1Value = try await d1
                let d2Value = try await d2
                #expect(d1Value != d2Value)

                let callCount = await test.callCount
                #expect(callCount == 2)
            }()
        }
    }
}
