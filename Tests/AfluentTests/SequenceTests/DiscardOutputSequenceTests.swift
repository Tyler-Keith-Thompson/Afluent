//
//  DiscardOutputSequenceTests.swift
//
//
//  Created by Tyler Thompson on 12/10/23.
//

import Afluent
import Foundation
import XCTest

final class DiscardOutputSequenceTests: XCTestCase {
    func testDiscardingOutputChangesToVoid() async throws {
        try await DeferredTask {
            1
        }
        .toAsyncSequence()
        .discardOutput()
        .map { XCTAssert(true) }
        .first()
    }
}
