//
//  RetainTests.swift
//
//
//  Created by Tyler Thompson on 10/30/23.
//

import Afluent
import Foundation
import XCTest

final class RetainTests: XCTestCase {
    func testLazyCachesResult() async throws {
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
            throw URLError(.badURL)
        }
        .retry()
        .execute()

        let callCount = await test.callCount
        XCTAssertEqual(callCount, 1)
    }

    func testLazyDoesNotAffectFullChain() async throws {
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
            throw URLError(.badURL)
        }
        .retry()
        .execute()

        let callCount = await test.callCount
        XCTAssertEqual(callCount, 3)
    }

    func testLazyDoesNotCacheError() async throws {
        actor Test {
            var callCount = 0
            func increment() { callCount += 1 }
        }
        let test = Test()

        try? await DeferredTask {
            await test.increment()
            throw URLError(.badURL)
        }
        .retain()
        .retry()
        .execute()

        let callCount = await test.callCount
        XCTAssertEqual(callCount, 2)
    }
}
