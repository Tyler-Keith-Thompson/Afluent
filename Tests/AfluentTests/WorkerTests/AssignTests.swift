//
//  AssignTests.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Foundation
import Afluent
import XCTest

final class AssignTests: XCTestCase {
    func testAssignToProperty() async throws {
        class Test {
            var val = ""
        }
        
        let test = Test()
        
        try await DeferredTask { "test" }
            .assign(to: \.val, on: test)
        
        XCTAssertEqual(test.val, "test")
    }
}
