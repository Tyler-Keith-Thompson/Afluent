//
//  DiscardOutputTests.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Afluent
import Foundation
import XCTest

final class DiscardOutputTests: XCTestCase {
    func testDiscardingOutputChangesToVoid() async throws {
        try await DeferredTask {
            1
        }
        .discardOutput()
        .map { XCTAssert(true) }
        .execute()
    }
}
