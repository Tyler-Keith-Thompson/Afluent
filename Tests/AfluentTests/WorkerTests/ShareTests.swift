//
//  ShareTests.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Afluent
import Foundation
import XCTest

final class ShareTests: XCTestCase {
    func testUnsharedTaskExecutesRepeatedly() async throws {
        let exp = expectation(description: "called")
        exp.expectedFulfillmentCount = 3

        actor Test {
            var arr = [String]()
            func append(_ str: String) {
                arr.append(str)
            }
        }

        let test = Test()

        let t = DeferredTask {
            await test.append("called")
            exp.fulfill()
        }

        t.run()
        t.run()
        t.run()

        await fulfillment(of: [exp], timeout: 0.01)
        let copy = await test.arr
        XCTAssertEqual(copy, ["called", "called", "called"])
    }

    func testUnsharedTaskExecutesRepeatedly_WithResult() async throws {
        actor Test {
            var arr = [String]()
            func append(_ str: String) {
                arr.append(str)
            }
        }

        let test = Test()

        let t = DeferredTask {
            await test.append("called")
        }

        try await t.execute()
        try await t.execute()
        try await t.execute()

        let copy = await test.arr
        XCTAssertEqual(copy, ["called", "called", "called"])
    }

    func testSharedTaskExecutesOnce() async throws {
        let exp = expectation(description: "called")
        actor Test {
            var arr = [String]()
            func append(_ str: String) {
                arr.append(str)
            }
        }

        let test = Test()

        let t = DeferredTask {
            await test.append("called")
            exp.fulfill()
        }.share()

        t.run()
        t.run()
        t.run()

        await fulfillment(of: [exp], timeout: 0.01)
        let copy = await test.arr
        XCTAssertEqual(copy, ["called"])
    }

    func testSharedTaskExecutesOnce_WithResult() async throws {
        actor Test {
            var arr = [String]()
            func append(_ str: String) {
                arr.append(str)
            }
        }

        let test = Test()

        let t = DeferredTask {
            await test.append("called")
        }.share()

        try await t.execute()
        try await t.execute()
        try await t.execute()

        let copy = await test.arr
        XCTAssertEqual(copy, ["called"])
    }

    func testSharedTaskExecutesOnce_WithResult_SharedToAllSubscribers() async throws {
        let t = DeferredTask {
            1
        }.share()

        let v1 = try await t.execute()
        let v2 = try await t.execute()
        let v3 = try await t.execute()
        XCTAssertEqual(v1, 1)
        XCTAssertEqual(v2, 1)
        XCTAssertEqual(v3, 1)
    }
}
