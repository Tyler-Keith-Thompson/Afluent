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
            _ = try await d1
            _ = try await d2

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
            _ = try await d1
            await clock.advance(by: .milliseconds(16))
            _ = try await d2

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
                .shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation, keys: 1)
            }

            let uow = unitOfWork()
            async let d1 = uow.execute()
            #expect(!cache.cache.isEmpty)
            async let d2 = DeferredTask {}
                .delay(for: .milliseconds(5), clock: clock)
                .flatMap { unitOfWork() }
                .execute()

            await clock.advance(by: .milliseconds(11))
            _ = try await d1
            _ = try await d2

            let callCount = await test.callCount
            #expect(callCount == 1)
        }
    }

    @Test func sharingFromCacheCancelAndRestartCancelsInFlightRequest() async throws {
        try await withMainSerialExecutor {
            let cache = AUOWCache()
            let clock = TestClock()

            @Sendable func unitOfWork() -> some AsynchronousUnitOfWork<String> {
                DeferredTask {
                    UUID().uuidString
                }
                .delay(for: .milliseconds(10), clock: clock)
                .shareFromCache(cache, strategy: .cancelAndRestart)
            }

            async let _r1 = Result { try await unitOfWork().execute() }
            async let _r2 = Result { try await unitOfWork().execute() }

            await clock.advance(by: .milliseconds(11))
            let r1 = await _r1
            let r2 = await _r2

            #expect(throws: CancellationError.self) {
                try r1.get()
            }
            _ = try r2.get()
        }
    }

    @Test func sharingFromCacheCancelAndRestartAfterCompletion() async throws {
        try await withMainSerialExecutor {
            let cache = AUOWCache()
            let clock = TestClock()

            @Sendable func unitOfWork() -> some AsynchronousUnitOfWork<String> {
                DeferredTask {
                    UUID().uuidString
                }
                .delay(for: .milliseconds(10), clock: clock)
                .shareFromCache(cache, strategy: .cancelAndRestart)
            }

            async let _r1 = Result { try await unitOfWork().execute() }
            await clock.advance(by: .milliseconds(11))
            async let _r2 = Result { try await unitOfWork().execute() }
            await clock.advance(by: .milliseconds(11))

            let r1 = await _r1
            let r2 = await _r2

            _ = try r1.get()
            _ = try r2.get()
        }
    }
}
