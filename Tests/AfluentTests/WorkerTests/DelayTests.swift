//
//  DelayTests.swift
//  
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation
import Afluent
import XCTest

final class DelayTests: XCTestCase {
    func testAssertNoFailureDoesNotThrowIfThereIsNoFailure() throws {
        let exp = self.expectation(description: "thing happened")
        let date = Date()
        try DeferredTask { }
            .delay(for: .milliseconds(10))
            .map { _ in exp.fulfill() }
            .run()

        self.wait(for: [exp], timeout: 0.02)
        XCTAssert(Date().timeIntervalSince(date) > Measurement<UnitDuration>(value: 10, unit: .milliseconds).converted(to: .seconds).value)
    }
}
