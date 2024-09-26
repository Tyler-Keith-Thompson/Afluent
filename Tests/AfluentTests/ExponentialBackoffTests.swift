//
//  ExponentialBackoffTests.swift
//  Afluent
//
//  Created by Tyler Thompson on 9/19/24.
//

import Testing
import Foundation
import Clocks

import Afluent

struct ExponentialbackoffTests {
    @Test func taskCanRetryADefinedNumberOfTimes() async throws {
        actor Test {
            var arr = [String]()
            func append(_ str: String) {
                arr.append(str)
            }
        }

        let test = Test()
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        let clock = TestClock()

        var iterator = stream.makeAsyncIterator()
        DeferredTask {
            await test.append("called")
            continuation.yield()
        }
        .tryMap { _ in throw GeneralError.e1 }
        .retry(RetryByBackoffStrategy(ExponentialBackoffStrategy(base: 2, maxCount: 4), clock: clock, durationUnit: { .seconds($0) }))
        .catch { err in
            DeferredTask {
                continuation.finish()
                throw err
            }
        }
        .run()
        
        #expect(await test.arr.count == 0)
        await clock.advance(by: .seconds(2))
        await iterator.next()
        #expect(await test.arr.count == 2)
        await clock.advance(by: .seconds(4))
        await iterator.next()
        #expect(await test.arr.count == 3)
        await clock.advance(by: .seconds(4))
        #expect(await test.arr.count == 3)
        await clock.advance(by: .seconds(4))
        await iterator.next()
        #expect(await test.arr.count == 4)
        await iterator.next()
        await clock.advance(by: .seconds(16))
        #expect(await iterator.next() == nil)
    }
    
    @Test func taskCanRetryADefinedNumberOfTimes_WithMaxDelay() async throws {
        actor Test {
            var arr = [String]()
            func append(_ str: String) {
                arr.append(str)
            }
        }

        let test = Test()
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        let clock = TestClock()

        var iterator = stream.makeAsyncIterator()
        DeferredTask {
            await test.append("called")
            continuation.yield()
        }
        .tryMap { _ in throw GeneralError.e1 }
        .retry(RetryByBackoffStrategy(ExponentialBackoffStrategy(base: 2, maxCount: 4, maxDelay: .seconds(1)), clock: clock, durationUnit: { .seconds($0) }))
        .run()
        
        #expect(await test.arr.count == 0)
        await clock.advance(by: .seconds(1))
        await iterator.next()
        #expect(await test.arr.count == 2)
        await clock.advance(by: .seconds(1))
        await iterator.next()
        #expect(await test.arr.count == 3)
        await clock.advance(by: .seconds(1))
        await iterator.next()
        #expect(await test.arr.count == 4)
    }
}
