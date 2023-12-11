//
//  ZipTests.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Afluent
import Foundation
import XCTest

final class ZipTests: XCTestCase {
    func testZipCombinesTasks_WithExplicitFailure() async throws {
        let t1 = DeferredTask<Int> { 1 }

        let t2 = DeferredTask<String> { "A" }
        let t3 = t2.zip(t1)
        let val = try await t3.execute() // Steak sauce!!!
        XCTAssertEqual(val.0, "A")
        XCTAssertEqual(val.1, 1)
    }

    func testZipCombinesTasks() async throws {
        let t1 = DeferredTask { 1 }

        let t2 = DeferredTask { "A" }
        let t3 = t2.zip(t1)
        let val = try await t3.execute() // Steak sauce!!!
        XCTAssertEqual(val.0, "A")
        XCTAssertEqual(val.1, 1)
    }

    func testZipTransformCombinesTasks_WithExplicitFailure() async throws {
        let t1 = DeferredTask<Int> { 1 }

        let t2 = DeferredTask<String> { "A" }
        let t3 = t2.zip(t1) { $0 + String(describing: $1) }
        let val = try await t3.execute() // Steak sauce!!!
        XCTAssertEqual(val, "A1")
    }

    func testZipTransformCombinesTasks() async throws {
        let t1 = DeferredTask { 1 }

        let t2 = DeferredTask { "A" }
        let t3 = t2.zip(t1) { $0 + String(describing: $1) }
        let val = try await t3.execute() // Steak sauce!!!
        XCTAssertEqual(val, "A1")
    }

    func testZip3CombinesTasks_WithExplicitFailure() async throws {
        let t1 = DeferredTask<Int> { 1 }
        let t2 = DeferredTask<String> { "A" }
        let t3 = DeferredTask<Bool> { true }

        let t4 = t2.zip(t1, t3)
        let val = try await t4.execute() // Steak sauce!!!
        XCTAssertEqual(val.0, "A")
        XCTAssertEqual(val.1, 1)
        XCTAssertEqual(val.2, true)
    }

    func testZip3CombinesTasks() async throws {
        let t1 = DeferredTask { 1 }
        let t2 = DeferredTask { "A" }
        let t3 = DeferredTask { true }

        let t4 = t2.zip(t1, t3)
        let val = try await t4.execute() // Steak sauce!!!
        XCTAssertEqual(val.0, "A")
        XCTAssertEqual(val.1, 1)
        XCTAssertEqual(val.2, true)
    }

    func testZip3TransformCombinesTasks_WithExplicitFailure() async throws {
        let t1 = DeferredTask<Int> { 1 }
        let t2 = DeferredTask<String> { "A" }
        let t3 = DeferredTask<Bool> { true }

        let t4 = t2.zip(t1, t3) { $0 + String(describing: $1) + String(describing: $2) }
        let val = try await t4.execute() // Steak sauce!!!
        XCTAssertEqual(val, "A1true")
    }

    func testZip3TransformCombinesTasks() async throws {
        let t1 = DeferredTask { 1 }
        let t2 = DeferredTask { "A" }
        let t3 = DeferredTask { true }

        let t4 = t2.zip(t1, t3) { $0 + String(describing: $1) + String(describing: $2) }
        let val = try await t4.execute() // Steak sauce!!!
        XCTAssertEqual(val, "A1true")
    }

    func testZip4CombinesTasks_WithExplicitFailure() async throws {
        let t1 = DeferredTask<Int> { 1 }
        let t2 = DeferredTask<String> { "A" }
        let t3 = DeferredTask<Bool> { true }
        let t4 = DeferredTask<Character> { Character("!") }

        let t5 = t2.zip(t1, t3, t4)
        let val = try await t5.execute() // Steak sauce!!!
        XCTAssertEqual(val.0, "A")
        XCTAssertEqual(val.1, 1)
        XCTAssertEqual(val.2, true)
        XCTAssertEqual(val.3, Character("!"))
    }

    func testZip4CombinesTasks() async throws {
        let t1 = DeferredTask { 1 }
        let t2 = DeferredTask { "A" }
        let t3 = DeferredTask { true }
        let t4 = DeferredTask { Character("!") }

        let t5 = t2.zip(t1, t3, t4)
        let val = try await t5.execute() // Steak sauce!!!
        XCTAssertEqual(val.0, "A")
        XCTAssertEqual(val.1, 1)
        XCTAssertEqual(val.2, true)
        XCTAssertEqual(val.3, Character("!"))
    }

    func testZip4TransformCombinesTasks_WithExplicitFailure() async throws {
        let t1 = DeferredTask<Int> { 1 }
        let t2 = DeferredTask<String> { "A" }
        let t3 = DeferredTask<Bool> { true }
        let t4 = DeferredTask<Character> { Character("!") }

        let t5 = t2.zip(t1, t3, t4) { $0 + String(describing: $1) + String(describing: $2) + String(describing: $3) }
        let val = try await t5.execute() // Steak sauce!!!
        XCTAssertEqual(val, "A1true!")
    }

    func testZip4TransformCombinesTasks() async throws {
        let t1 = DeferredTask { 1 }
        let t2 = DeferredTask { "A" }
        let t3 = DeferredTask { true }
        let t4 = DeferredTask { Character("!") }

        let t5 = t2.zip(t1, t3, t4) { $0 + String(describing: $1) + String(describing: $2) + String(describing: $3) }
        let val = try await t5.execute() // Steak sauce!!!
        XCTAssertEqual(val, "A1true!")
    }
}
