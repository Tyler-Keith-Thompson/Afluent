//
//  TimeoutTests.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Afluent
import AfluentTesting
import Clocks
import ConcurrencyExtras
import Foundation
import Testing

struct TimeoutTests {
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func taskDoesNotTimeOutIfItCompletesInTime() async throws {
        let clock = TrackedTestClock()
        let val = try await DeferredTask { "test" }
            .timeout(.milliseconds(10), clock: clock)
            .execute()

        #expect(val == "test")
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func taskTimesOutIfItTakesTooLong() async throws {
        let clock = TrackedTestClock()

        let task = Task {
            try await DeferredTask { "test" }
                .delay(for: .milliseconds(20), clock: clock)
                .timeout(.milliseconds(10), clock: clock)
                .execute()
        }

        // Both the delay's and the timeout's sleeps must be registered before time moves.
        try await clock.advance(by: .milliseconds(11), whenSleeping: 2)

        let res = await task.result
        #expect { try res.get() } throws: { error in
            error.localizedDescription == "Timed out after waiting \(Duration.milliseconds(10))"
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func taskTimesOutIfItTakesTooLong_withSingleValueSubject() async throws {
        let clock = TrackedTestClock()

        let sub = SingleValueSubject<Void>()

        let task = Task {
            try await DeferredTask { try await sub.execute() }
                .timeout(.milliseconds(10), clock: clock)
                .execute()
        }

        try await clock.advance(by: .milliseconds(11), whenSleeping: 1)

        let res = await task.result
        #expect { try res.get() } throws: { error in
            error.localizedDescription == "Timed out after waiting \(Duration.milliseconds(10))"
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func taskTimesOutIfItTakesTooLong_AndCanCatchTimeoutError() async throws {
        let clock = TrackedTestClock()

        let task = Task {
            try await DeferredTask { "test" }
                .delay(for: .milliseconds(20), clock: clock)
                .timeout(.milliseconds(10), clock: clock)
                .catch(TimeoutError.timedOut) { error in
                    DeferredTask { "caught" }
                }
                .execute()
        }

        // Both the delay's and the timeout's sleeps must be registered before time moves.
        try await clock.advance(by: .milliseconds(11), whenSleeping: 2)

        let val = try await task.value

        #expect(val == "caught")
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func taskTimesOutIfItTakesTooLong_WithCustomError() async throws {
        let clock = TrackedTestClock()

        enum Err: Error {
            case e1
        }

        let task = Task {
            try await DeferredTask { "test" }
                .delay(for: .milliseconds(20), clock: clock)
                .timeout(.milliseconds(10), clock: clock, customError: Err.e1)
                .execute()
        }

        // Both the delay's and the timeout's sleeps must be registered before time moves.
        try await clock.advance(by: .milliseconds(11), whenSleeping: 2)

        let res = await task.result

        #expect { try res.get() } throws: { error in
            error as? Err == .e1
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("timeout cancels the upstream when it times out", .timeLimit(.minutes(1)))
    func timeoutCancelsTheUpstream() async throws {
        // The upstream waits on a stream that never yields, so only cancellation ends it; it reports what it saw.
        let (neverYields, neverYieldsContinuation) = AsyncStream<Void>.makeStream()
        let (upstreamStarted, upstreamStartedContinuation) = AsyncStream<Void>.makeStream()
        let (upstreamEnded, upstreamEndedContinuation) = AsyncStream<Bool>.makeStream()
        let clock = TrackedTestClock()
        let task = Task {
            try await DeferredTask {
                upstreamStartedContinuation.yield()
                for await _ in neverYields {}
                upstreamEndedContinuation.yield(Task.isCancelled)
            }
            .timeout(.seconds(1), clock: clock)
            .result
        }
        // The deadline passes only once the upstream is running, so it has work to cancel.
        for await _ in upstreamStarted { break }
        try await clock.advance(by: .seconds(1), whenSleeping: 1)
        let result = try await task.value
        func getResult() throws { try result.get() }
        #expect(throws: TimeoutError.self, performing: getResult)
        var upstreamWasCancelled: Bool?
        for await value in upstreamEnded {
            upstreamWasCancelled = value
            break
        }
        #expect(upstreamWasCancelled == true)
        neverYieldsContinuation.finish()
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("timeout passes on an error the upstream throws before the deadline", .timeLimit(.minutes(1)))
    func timeoutPassesOnTheUpstreamsError() async throws {
        struct Failed: Error {}
        // A test clock that is never advanced, so the deadline never comes.
        let clock = TestClock()
        let result = try await DeferredTask { throw Failed() }
            .timeout(.seconds(1), clock: clock)
            .result
        func getResult() throws { try result.get() }
        #expect(throws: Failed.self, performing: getResult)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("timeout with a Duration returns the upstream's value when it finishes in time")
    func timeoutWithADurationReturnsTheValue() async throws {
        let expected = 1
        let value = try await DeferredTask { expected }
            .timeout(.seconds(60))
            .execute()
        #expect(value == expected)
    }
}
