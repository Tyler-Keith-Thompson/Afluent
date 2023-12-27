//
//  DelayTests.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Afluent
import Clocks
import Foundation
import XCTest

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
final class DelayTests: XCTestCase {
    func testDeferredTaskCanDelayForAnExpectedDuration() async throws {
        let clock = TestClock()
        var finished = false
        DeferredTask { }
            .delay(for: .milliseconds(10), clock: clock, tolerance: nil)
            .handleEvents(receiveOutput: { _ in finished = true })
            .run()

        await clock.advance(by: .milliseconds(1))
        XCTAssertFalse(finished)
        await clock.advance(by: .milliseconds(9))
        XCTAssert(finished)
    }
}
