//
//  WithUnretainedTests.swift
//
//
//  Created by Daniel Bachar on 11/8/23.
//
import Afluent

import Foundation
import XCTest

final class WithUnretainedTests: XCTestCase {
    class MyType { }

    func testWithUnretainedHolds() async throws {
        let myTypeInstance = MyType()

        try await DeferredTask { 1 }
            .withUnretained(myTypeInstance, resultSelector: { myType, _ in
                XCTAssertNotNil(myType)
            })
            .execute()
    }

    func testWithUnretainedThrows() async throws {
        do {
            try await DeferredTask { 1 }
                .withUnretained(MyType(), resultSelector: { _, _ in })
                .execute()
            XCTFail("Should throw if failed to retain")
        } catch {
            XCTAssertEqual(error as? UnretainedError, UnretainedError.failedRetaining)
        }
    }
}
