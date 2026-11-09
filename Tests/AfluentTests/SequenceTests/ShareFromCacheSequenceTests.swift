//
//  ShareFromCacheSequenceTests.swift
//  Afluent
//
//  Created by Tyler Thompson on 10/19/24.
//

import AfluentTesting
import Atomics
import Clocks
import ConcurrencyExtras
import Foundation
import Testing

@testable import Afluent

struct ShareFromCacheSequenceTests {
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func sharingFromCacheWithNoKey() async throws {
        actor Test {
            var callCount = 0

            func increment() {
                callCount += 1
            }
        }
        let clock = TrackedTestClock()
        let d2Subscribed = ManagedAtomic(false)
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
                return sequence().handleEvents(receiveMakeIterator: {
                    d2Subscribed.store(true, ordering: .sequentiallyConsistent)
                })
            }
            .collect().first()

        // d2 must subscribe to the cached sequence while d1 is still in flight.
        try await clock.advance(by: .milliseconds(5), whenSleeping: 2)
        try await wait(
            until: d2Subscribed.load(ordering: .sequentiallyConsistent), timeout: .seconds(2))
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
        let cache = AsyncSequenceCache()
        let clock = TrackedTestClock()
        let d2Subscribed = ManagedAtomic(false)

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
                d2Subscribed.store(true, ordering: .sequentiallyConsistent)
                return sequence()
            }
            .collect().first()

        try await clock.advance(by: .milliseconds(11), whenSleeping: 2)
        _ = try await d1
        // d2 wakes at 15 and starts a new sequence, whose own 10 ms delay must be registered before time moves on.
        await clock.advance(by: .milliseconds(4))
        try await wait(
            until: d2Subscribed.load(ordering: .sequentiallyConsistent), timeout: .seconds(2))
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
        let cache = AsyncSequenceCache()
        let clock = TrackedTestClock()

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
        let cache = AsyncSequenceCache()
        let clock = TrackedTestClock()
        let d2Subscribed = ManagedAtomic(false)

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
            .flatMap {
                sequence().handleEvents(receiveMakeIterator: {
                    d2Subscribed.store(true, ordering: .sequentiallyConsistent)
                })
            }
            .collect().first()

        try await clock.advance(by: .milliseconds(5), whenSleeping: 2)
        try await wait(
            until: d2Subscribed.load(ordering: .sequentiallyConsistent), timeout: .seconds(2))
        await clock.advance(by: .milliseconds(6))
        _ = try await d1
        _ = try await d2

        let callCount = await test.callCount
        #expect(callCount == 1)
    }
}
