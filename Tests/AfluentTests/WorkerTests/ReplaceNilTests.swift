//
//  ReplaceNilTests.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Afluent
import Foundation
import XCTest

final class ReplaceNilTests: XCTestCase {
    func testReplaceNilTransformsValue() async throws {
        let val = try await DeferredTask { nil as Int? }
            .replaceNil(with: 0)
            .execute()

        XCTAssertEqual(val, 0)
    }

    func testReplaceNilDoesNotTransformValue_IfValueExists() async throws {
        let val = try await DeferredTask { 1 as Int? }
            .replaceNil(with: 0)
            .execute()

        XCTAssertEqual(val, 1)
    }
}
