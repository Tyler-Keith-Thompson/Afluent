//
//  ShareFromCacheSequenceTests.swift
//  Afluent
//
//  Created by Tyler Thompson on 10/19/24.
//

@_spi(Experimental) @testable import Afluent
import Clocks
import ConcurrencyExtras
import Foundation
import Testing

struct ShareFromCacheSequenceTests {
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
            let cache = AsyncSequenceCache()

            @Sendable func sequence() -> AnyAsyncSequence<String> {
                DeferredTask {
                    await test.increment()
                    return UUID().uuidString
                }
                .toAsyncSequence()
                .delay(for: .milliseconds(10), clock: clock)
                .shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation)
                .eraseToAnyAsyncSequence()
            }

            let uow = sequence()
            async let d1 = uow.collect().first()
            #expect(!cache.cache.isEmpty)
            async let d2 = DeferredTask {}
                .toAsyncSequence()
                .delay(for: .milliseconds(5), clock: clock)
                .flatMap {
                    #expect(!cache.cache.isEmpty)
                    let uow = sequence()
                    return uow
                }
                .collect().first()

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
            let cache = AsyncSequenceCache()
            let clock = TestClock()

            @Sendable func sequence() -> AnyAsyncSequence<String> {
                DeferredTask {
                    await test.increment()
                    return UUID().uuidString
                }
                .toAsyncSequence()
                .delay(for: .milliseconds(10), clock: clock)
                .shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation)
                .eraseToAnyAsyncSequence()
            }

            let uow = sequence()
            async let d1 = uow.collect().first()
            #expect(!cache.cache.isEmpty)
            async let d2 = DeferredTask {}
                .toAsyncSequence()
                .delay(for: .milliseconds(15), clock: clock)
                .flatMap {
                    #expect(cache.cache.isEmpty)
                    return sequence()
                }
                .collect().first()

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
            let cache = AsyncSequenceCache()
            let clock = TestClock()

            @Sendable func sequence() -> AnyAsyncSequence<String> {
                DeferredTask {
                    await test.increment()
                    throw Err.e1
                }
                .toAsyncSequence()
                .delay(for: .milliseconds(10), clock: clock)
                .shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation)
                .eraseToAnyAsyncSequence()
            }

            let uow = sequence()
            async let d1 = uow.collect().first()
            #expect(!cache.cache.isEmpty)
            async let d2 = DeferredTask {}
                .toAsyncSequence()
                .delay(for: .milliseconds(15), clock: clock)
                .flatMap {
                    #expect(cache.cache.isEmpty)
                    return sequence()
                }
                .collect().first()

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
            let cache = AsyncSequenceCache()
            let clock = TestClock()

            @Sendable func sequence() -> AnyAsyncSequence<String> {
                DeferredTask {
                    await test.increment()
                    return UUID().uuidString
                }
                .toAsyncSequence()
                .delay(for: .milliseconds(10), clock: clock)
                .shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation, keys: 1)
                .eraseToAnyAsyncSequence()
            }

            let uow = sequence()
            async let d1 = uow.collect().first()
            #expect(!cache.cache.isEmpty)
            async let d2 = DeferredTask {}
                .toAsyncSequence()
                .delay(for: .milliseconds(5), clock: clock)
                .flatMap { sequence() }
                .collect().first()

            await clock.advance(by: .milliseconds(11))
            _ = try await d1
            _ = try await d2

            let callCount = await test.callCount
            #expect(callCount == 1)
        }
    }
}
