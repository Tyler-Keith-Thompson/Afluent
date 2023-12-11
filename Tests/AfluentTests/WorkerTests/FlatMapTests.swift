//
//  FlatMapTests.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Afluent
import Foundation
import XCTest

final class FlatMapTests: XCTestCase {
    func testFlatMapTransformsValue() async throws {
        let val = try await DeferredTask { 1 }
            .flatMap { val in
                DeferredTask { val }
                    .map { String(describing: $0) }
            }
            .execute()

        XCTAssertEqual(val, "1")
    }

    func testFlatMapOrdersCorrectly() async throws {
        actor Test {
            var arr = [String]()
            func append(_ str: String) {
                arr.append(str)
            }
        }

        let test = Test()

        try await DeferredTask {
            try await Task.sleep(nanoseconds: 10000)
            await test.append("1")
        }.flatMap {
            DeferredTask {
                await test.append("2")
            }
        }
        .execute()

        let copy = await test.arr
        XCTAssertEqual(copy, ["1", "2"])
    }

    func testFlatMapOrdersCorrectly_No_Throwing() async throws {
        actor Test {
            var arr = [String]()
            func append(_ str: String) {
                arr.append(str)
            }
        }

        let test = Test()

        try await DeferredTask {
            try! await Task.sleep(nanoseconds: 10000)
            await test.append("1")
        }.flatMap {
            DeferredTask {
                await test.append("2")
            }
        }
        .execute()

        let copy = await test.arr
        XCTAssertEqual(copy, ["1", "2"])
    }

    func testFlatMapThrowsError() async throws {
        let val = try await DeferredTask { 1 }
            .flatMap { _ in
                DeferredTask {
                    throw URLError(.badURL)
                }
            }
            .result

        XCTAssertThrowsError(try val.get()) { error in
            XCTAssertEqual(error as? URLError, URLError(.badURL))
        }
    }
}
