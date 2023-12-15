//
//  DelayTests.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Afluent
import Foundation
import XCTest

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
final class DelayTests: XCTestCase {
    func testAssertNoFailureDoesNotThrowIfThereIsNoFailure() throws {
        let exp = expectation(description: "thing happened")
        let date = Date()
        DeferredTask { }
            .delay(for: .milliseconds(10))
            .map { _ in exp.fulfill() }
            .run()

        wait(for: [exp], timeout: 0.02)
        XCTAssert(Date().timeIntervalSince(date) > Measurement<UnitDuration>(value: 10, unit: .milliseconds).converted(to: .seconds).value)
    }
}
