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
import Testing

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct TimeoutTests {
    @Test func taskDoesNotTimeOutIfItCompletesInTime() async throws {
        try await withMainSerialExecutor {
            let val = try await DeferredTask { "test" }
                .timeout(.milliseconds(10))
                .execute()

            #expect(val == "test")
        }
    }

    @Test func taskTimesOutIfItTakesTooLong() async throws {
        await withMainSerialExecutor {
            let clock = TestClock()

            let task = Task {
                try await DeferredTask { "test" }
                    .delay(for: .milliseconds(20))
                    .timeout(.milliseconds(10), clock: clock)
                    .execute()
            }

            await clock.advance(by: .milliseconds(11))

            let res = await task.result
            #expect(throws: (any Error).self) { try res.get() }
        }
    }

    @Test func taskTimesOutIfItTakesTooLong_WithCustomError() async throws {
        await withMainSerialExecutor {
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

            #expect { try res.get() } throws: { error in
                error as? Err == .e1
            }
        }
    }
}
