//
//  TimeoutTests.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation
import Afluent
import XCTest

final class TimeoutTests: XCTestCase {
    func testTaskDoesNotTimeOutIfItCompletesInTime() async throws {
        let val = try await DeferredTask { "test" }
            .timeout(.milliseconds(10))
            .execute()
        
        XCTAssertEqual(val, "test")
    }
    
    func testTaskTimesOutIfItTakesTooLong() async throws {
        let res = try await DeferredTask { "test" }
            .delay(for: .milliseconds(20))
            .timeout(.milliseconds(10))
            .result
        
        XCTAssertThrowsError(try res.get())
    }
}
