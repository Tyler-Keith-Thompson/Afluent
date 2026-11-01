//
//  ExponentialBackoffTests.swift
//  Afluent
//
//  Created by Tyler Thompson on 9/19/24.
//

import Afluent
import AfluentTesting
import Clocks
import Foundation
import Testing

struct ExponentialbackoffTests {
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test func taskCanRetryADefinedNumberOfTimes() async throws {
        actor Test {
            var arr = [String]()
            func append(_ str: String) {
                arr.append(str)
            }
        }

        let test = Test()
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        let clock = TrackedTestClock()

        var iterator = stream.makeAsyncIterator()
        DeferredTask {
            await test.append("called")
            continuation.yield()
        }
        .tryMap { _ in throw GeneralError.e1 }
        .retry(
            RetryByBackoffStrategy(
                ExponentialBackoffStrategy(base: 2, maxCount: 4), clock: clock,
                durationUnit: { .seconds($0) })
        )
        .catch { err in
            DeferredTask {
                continuation.finish()
                throw err
            }
        }
        .run()

        // Each attempt yields once, so `iterator.next()` returns when that attempt has run. Time only moves
        // once the backoff sleep is registered.
        await iterator.next()
        #expect(await test.arr.count == 1)
        try await clock.advance(by: .seconds(2), whenSleeping: 1)
        await iterator.next()
        #expect(await test.arr.count == 2)
        try await clock.advance(by: .seconds(4), whenSleeping: 1)
        await iterator.next()
        #expect(await test.arr.count == 3)
        try await clock.advance(by: .seconds(4), whenSleeping: 1)
        #expect(await test.arr.count == 3)
        await clock.advance(by: .seconds(4))
        await iterator.next()
        #expect(await test.arr.count == 4)
        await clock.advance(by: .seconds(16))
        #expect(await iterator.next() == nil)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test func taskCanRetryADefinedNumberOfTimes_WithMaxDelay() async throws {
        actor Test {
            var arr = [String]()
            func append(_ str: String) {
                arr.append(str)
            }
        }

        let test = Test()
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        let clock = TrackedTestClock()

        var iterator = stream.makeAsyncIterator()
        DeferredTask {
            await test.append("called")
            continuation.yield()
        }
        .tryMap { _ in throw GeneralError.e1 }
        .retry(
            RetryByBackoffStrategy(
                ExponentialBackoffStrategy(base: 2, maxCount: 4, maxDelay: .seconds(1)),
                clock: clock, durationUnit: { .seconds($0) })
        )
        .run()

        await iterator.next()
        #expect(await test.arr.count == 1)
        try await clock.advance(by: .seconds(1), whenSleeping: 1)
        await iterator.next()
        #expect(await test.arr.count == 2)
        try await clock.advance(by: .seconds(1), whenSleeping: 1)
        await iterator.next()
        #expect(await test.arr.count == 3)
        try await clock.advance(by: .seconds(1), whenSleeping: 1)
        await iterator.next()
        #expect(await test.arr.count == 4)
    }
}
