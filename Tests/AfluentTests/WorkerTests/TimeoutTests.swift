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

struct TimeoutTests {
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func taskDoesNotTimeOutIfItCompletesInTime() async throws {
        let clock = TestClock()
        let val = try await DeferredTask { "test" }
            .timeout(.milliseconds(10), clock: clock)
            .execute()

        #expect(val == "test")
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func taskTimesOutIfItTakesTooLong() async throws {
        let clock = TestClock()

        let task = Task {
            try await DeferredTask { "test" }
                .delay(for: .milliseconds(20), clock: clock)
                .timeout(.milliseconds(10), clock: clock)
                .execute()
        }

        await clock.advance(by: .milliseconds(11))

        let res = await task.result
        #expect { try res.get() } throws: { error in 
            error.localizedDescription == "Timed out after waiting \(Duration.milliseconds(10))"
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func taskTimesOutIfItTakesTooLong_AndCanCatchTimeoutError() async throws {
        let clock = TestClock()

        let task = Task {
            try await DeferredTask { "test" }
                .delay(for: .milliseconds(20), clock: clock)
                .timeout(.milliseconds(10), clock: clock)
                .catch(TimeoutError.timedOut) { error in
                    DeferredTask { "caught" }
                }
                .execute()
        }

        await clock.advance(by: .milliseconds(11))

        let val = try await task.value

        #expect(val == "caught")
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func taskTimesOutIfItTakesTooLong_WithCustomError() async throws {
        let clock = TestClock()

        enum Err: Error {
            case e1
        }

        let task = Task {
            try await DeferredTask { "test" }
                .delay(for: .milliseconds(20), clock: clock)
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
