//
//  RetainTests.swift
//
//
//  Created by Tyler Thompson on 10/30/23.
//

import Afluent
import Foundation
import Testing

struct RetainTests {
    @Test func lazyCachesResult() async throws {
        actor Test {
            var callCount = 0
            func increment() { callCount += 1 }
        }
        let test = Test()

        try? await DeferredTask {
            await test.increment()
        }
        .retain()
        .tryMap {
            throw GeneralError.e1
        }
        .retry()
        .execute()

        let callCount = await test.callCount
        #expect(callCount == 1)
    }

    @Test func lazyDoesNotAffectFullChain() async throws {
        actor Test {
            var callCount = 0
            func increment() { callCount += 1 }
        }
        let test = Test()

        try? await DeferredTask {
            await test.increment()
        }
        .retain()
        .map {
            await test.increment()
        }
        .tryMap {
            throw GeneralError.e1
        }
        .retry()
        .execute()

        let callCount = await test.callCount
        #expect(callCount == 3)
    }

    @Test func lazyDoesNotCacheError() async throws {
        actor Test {
            var callCount = 0
            func increment() { callCount += 1 }
        }
        let test = Test()

        try? await DeferredTask {
            await test.increment()
            throw GeneralError.e1
        }
        .retain()
        .retry()
        .execute()

        let callCount = await test.callCount
        #expect(callCount == 2)
    }
}
