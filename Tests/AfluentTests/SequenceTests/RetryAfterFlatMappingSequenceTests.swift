//
//  RetryAfterFlatMappingSequenceTests.swift
//
//
//  Created by Tyler Thompson on 11/28/23.
//

import Afluent
import Foundation
import Testing

struct RetryAfterFlatMappingSequenceTests {
    @Test func taskCanRetryADefinedNumberOfTimes() async throws {
        actor Test {
            var arr = [String]()
            func append(_ str: String) {
                arr.append(str)
            }
        }

        let test = Test()
        let retryCount = UInt.random(in: 2 ... 10)

        let t = Task {
            try await DeferredTask {
                await test.append("called")
            }
            .toAsyncSequence()
            .map { _ in throw URLError(.badURL) }
            .retry(retryCount) { _ in
                DeferredTask {
                    await test.append("flatMap")
                }
                .toAsyncSequence()
            }
            .first()
        }

        _ = await t.result

        let copy = await test.arr
        #expect(UInt(copy.count) == (retryCount * 2) + 1)
    }

    @Test func taskCanRetryZero_DoesNothing() async throws {
        actor Test {
            var arr = [String]()
            func append(_ str: String) {
                arr.append(str)
            }
        }

        let test = Test()

        let t = Task {
            try await DeferredTask {
                await test.append("called")
            }
            .toAsyncSequence()
            .map { _ in throw URLError(.badURL) }
            .retry(0) { _ in
                DeferredTask {
                    await test.append("flatMap")
                }
                .toAsyncSequence()
            }
            .first()
        }

        _ = await t.result

        let copy = await test.arr
        #expect(UInt(copy.count) == 1)
    }

    @Test func taskCanRetryDefaultsToOnce() async throws {
        actor Test {
            var arr = [String]()
            func append(_ str: String) {
                arr.append(str)
            }
        }

        let test = Test()

        let t = Task {
            try await DeferredTask {
                await test.append("called")
            }
            .toAsyncSequence()
            .map { _ in throw URLError(.badURL) }
            .retry { _ in
                DeferredTask {
                    await test.append("flatMap")
                }
                .toAsyncSequence()
            }
            .first()
        }

        _ = await t.result

        let copy = await test.arr
        #expect(UInt(copy.count) == 3)
    }

    @Test func taskCanRetryWithoutError_DoesNothing() async throws {
        actor Test {
            var arr = [String]()
            func append(_ str: String) {
                arr.append(str)
            }
        }

        let test = Test()

        let t = Task {
            try await DeferredTask {
                await test.append("called")
            }
            .toAsyncSequence()
            .retry(10) { _ in
                DeferredTask {
                    await test.append("flatMap")
                }
                .toAsyncSequence()
            }
            .first()
        }

        _ = await t.result

        let copy = await test.arr
        #expect(UInt(copy.count) == 1)
    }
}
