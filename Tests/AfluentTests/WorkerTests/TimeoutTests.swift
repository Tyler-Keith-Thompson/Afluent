//
//  TimeoutTests.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Afluent
import Clocks
import ConcurrencyExtras
import Foundation
import XCTest

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
final class TimeoutTests: XCTestCase {
    func testTaskDoesNotTimeOutIfItCompletesInTime() async throws {
        try await withMainSerialExecutor {
            let val = try await DeferredTask { "test" }
                .timeout(.milliseconds(10))
                .execute()

            XCTAssertEqual(val, "test")
        }
    }

    func testTaskTimesOutIfItTakesTooLong() async throws {
        try await withMainSerialExecutor {
            let clock = TestClock()

            let task = Task {
                try await DeferredTask { "test" }
                    .delay(for: .milliseconds(20))
                    .timeout(.milliseconds(10), clock: clock)
                    .execute()
            }

            await clock.advance(by: .milliseconds(11))

            let res = await task.result
            XCTAssertThrowsError(try res.get())
        }
    }

    func testTaskTimesOutIfItTakesTooLong_WithCustomError() async throws {
        try await withMainSerialExecutor {
            let clock = TestClock()

            enum Err: Error {
                case e1
            }

            let task = Task {
                try await DeferredTask { "test" }
                    .delay(for: .milliseconds(20))
                    .timeout(.milliseconds(10), clock: clock, customError: Err.e1)
                    .execute()
            }

            await clock.advance(by: .milliseconds(11))

            let res = await task.result

            XCTAssertThrowsError(try res.get()) { error in
                XCTAssertEqual(error as? Err, .e1)
            }
        }
    }
}
