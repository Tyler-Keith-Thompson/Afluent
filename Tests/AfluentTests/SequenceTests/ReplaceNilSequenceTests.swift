//
//  ReplaceNilSequenceTests.swift
//
//
//  Created by Tyler Thompson on 12/19/23.
//

import Afluent
import Foundation
import XCTest

final class ReplaceNilSequenceTests: XCTestCase {
    func testReplaceNilTransformsValue() async throws {
        let val = try await DeferredTask { nil as Int? }
            .toAsyncSequence()
            .replaceNil(with: 0)
            .first()

        XCTAssertEqual(val, 0)
    }

    func testReplaceNilDoesNotTransformValue_IfValueExists() async throws {
        let val = try await DeferredTask { 1 as Int? }
            .toAsyncSequence()
            .replaceNil(with: 0)
            .first()

        XCTAssertEqual(val, 1)
    }
}
