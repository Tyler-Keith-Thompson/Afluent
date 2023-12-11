//
//  MapTests.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Afluent
import Foundation
import XCTest

final class MapTests: XCTestCase {
    func testMapTransformsValue() async throws {
        let val = try await DeferredTask { 1 }
            .map { String(describing: $0) }
            .execute()

        XCTAssertEqual(val, "1")
    }

    func testMapTransformsWithKeypath() async throws {
        struct Obj {
            let val = 0
            let other = 1
        }

        let val = try await DeferredTask { Obj() }
            .map(\.val)
            .execute()

        XCTAssertEqual(val, 0)
    }

    func testTryMapTransformsValue() async throws {
        let val = try await DeferredTask { 1 }
            .tryMap { String(describing: $0) }
            .execute()

        XCTAssertEqual(val, "1")
    }

    func testTryMapThrowsError() async throws {
        let val = try await DeferredTask { 1 }
            .tryMap { _ in throw URLError(.badURL) }
            .result

        XCTAssertThrowsError(try val.get()) { error in
            XCTAssertEqual(error as? URLError, URLError(.badURL))
        }
    }
}
