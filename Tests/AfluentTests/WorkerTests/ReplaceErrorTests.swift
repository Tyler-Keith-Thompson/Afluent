//
//  ReplaceErrorTests.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Afluent
import Foundation
import XCTest

final class ReplaceErrorTests: XCTestCase {
    func testReplaceErrorTransformsValue() async throws {
        let val = try await DeferredTask { throw URLError(.badURL) }
            .replaceError(with: -1)
            .execute()

        XCTAssertEqual(val, -1)
    }

    func testReplaceNilDoesNotTransformValue_IfNoErrorThrown() async throws {
        let val = try await DeferredTask { 1 }
            .replaceError(with: -1)
            .execute()

        XCTAssertEqual(val, 1)
    }
}
