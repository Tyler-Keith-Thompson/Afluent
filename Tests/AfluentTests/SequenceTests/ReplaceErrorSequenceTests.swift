//
//  ReplaceErrorSequenceTests.swift
//
//
//  Created by Tyler Thompson on 12/19/23.
//

import Afluent
import Foundation
import XCTest

final class ReplaceErrorSequenceTests: XCTestCase {
    func testReplaceErrorTransformsValue() async throws {
        let val = try await DeferredTask { throw URLError(.badURL) }
            .toAsyncSequence()
            .replaceError(with: -1)
            .first()

        XCTAssertEqual(val, -1)
    }

    func testReplaceNilDoesNotTransformValue_IfNoErrorThrown() async throws {
        let val = try await DeferredTask { 1 }
            .toAsyncSequence()
            .replaceError(with: -1)
            .first()

        XCTAssertEqual(val, 1)
    }
}
