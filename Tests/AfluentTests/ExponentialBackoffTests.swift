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
        .retry(RetryByBackoffStrategy(.binaryExponential(maxCount: 4), clock: clock))
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
    }

//    @Test func taskCanRetryZero_DoesNothing() async throws {
//        actor Test {
//            var arr = [String]()
//            func append(_ str: String) {
//                arr.append(str)
//            }
//        }
//
//        let test = Test()
//
//        let t = DeferredTask {
//            await test.append("called")
//        }
//        .tryMap { _ in throw GeneralError.e1 }
//        .retry(0)
//
//        _ = try await t.result
//
//        let copy = await test.arr
//        #expect(UInt(copy.count) == 1)
//    }
//
//    @Test func taskCanRetryDefaultsToOnce() async throws {
//        actor Test {
//            var arr = [String]()
//            func append(_ str: String) {
//                arr.append(str)
//            }
//        }
//
//        let test = Test()
//
//        let t = DeferredTask {
//            await test.append("called")
//        }
//        .tryMap { _ in throw GeneralError.e1 }
//        .retry()
//
//        _ = try await t.result
//
//        let copy = await test.arr
//        #expect(UInt(copy.count) == 2)
//    }
//
//    @Test func taskWithMultipleRetries_OnlyRetriesTheSpecifiedNumberOfTimes() async throws {
//        actor Test {
//            var arr = [String]()
//            func append(_ str: String) {
//                arr.append(str)
//            }
//        }
//
//        let test = Test()
//
//        let t = DeferredTask {
//            await test.append("called")
//        }
//        .tryMap { _ in throw GeneralError.e1 }
//        .retry()
//        .retry()
//
//        _ = try await t.result
//
//        let copy = await test.arr
//        #expect(UInt(copy.count) == 3)
//    }
//
//    @Test func taskCanRetryWithoutError_DoesNothing() async throws {
//        actor Test {
//            var arr = [String]()
//            func append(_ str: String) {
//                arr.append(str)
//            }
//        }
//
//        let test = Test()
//
//        let t = DeferredTask {
//            await test.append("called")
//        }
//        .retry(10)
//
//        _ = try await t.result
//
//        let copy = await test.arr
//        #expect(UInt(copy.count) == 1)
//    }
//    
//    @Test func taskCanRetryADefinedNumberOfTimes_WithStrategy() async throws {
//        actor Test {
//            var arr = [String]()
//            func append(_ str: String) {
//                arr.append(str)
//            }
//        }
//
//        let test = Test()
//        let retryCount = UInt.random(in: 2 ... 10)
//
//        let t = DeferredTask {
//            await test.append("called")
//        }
//        .tryMap { _ in throw GeneralError.e1 }
//        .retry(.byCount(retryCount))
//
//        _ = try await t.result
//
//        let copy = await test.arr
//        #expect(UInt(copy.count) == retryCount + 1)
//    }
//
//    @Test func taskCanRetryZero_DoesNothing_WithStrategy() async throws {
//        actor Test {
//            var arr = [String]()
//            func append(_ str: String) {
//                arr.append(str)
//            }
//        }
//
//        let test = Test()
//
//        let t = DeferredTask {
//            await test.append("called")
//        }
//        .tryMap { _ in throw GeneralError.e1 }
//        .retry(.byCount(0))
//
//        _ = try await t.result
//
//        let copy = await test.arr
//        #expect(UInt(copy.count) == 1)
//    }
//
//    @Test func taskCanRetryDefaultsToOnce_WithStrategy() async throws {
//        actor Test {
//            var arr = [String]()
//            func append(_ str: String) {
//                arr.append(str)
//            }
//        }
//
//        let test = Test()
//
//        let t = DeferredTask {
//            await test.append("called")
//        }
//        .tryMap { _ in throw GeneralError.e1 }
//        .retry(.byCount(1))
//
//        _ = try await t.result
//
//        let copy = await test.arr
//        #expect(UInt(copy.count) == 2)
//    }
//
//    @Test func taskWithMultipleRetries_OnlyRetriesTheSpecifiedNumberOfTimes_WithStrategy() async throws {
//        actor Test {
//            var arr = [String]()
//            func append(_ str: String) {
//                arr.append(str)
//            }
//        }
//
//        let test = Test()
//
//        let t = DeferredTask {
//            await test.append("called")
//        }
//        .tryMap { _ in throw GeneralError.e1 }
//        .retry(.byCount(1))
//        .retry(.byCount(1))
//
//        _ = try await t.result
//
//        let copy = await test.arr
//        #expect(UInt(copy.count) == 3)
//    }
//
//    @Test func taskCanRetryWithoutError_DoesNothing_WithStrategy() async throws {
//        actor Test {
//            var arr = [String]()
//            func append(_ str: String) {
//                arr.append(str)
//            }
//        }
//
//        let test = Test()
//
//        let t = DeferredTask {
//            await test.append("called")
//        }
//        .retry(.byCount(10))
//
//        _ = try await t.result
//
//        let copy = await test.arr
//        #expect(UInt(copy.count) == 1)
//    }
}
