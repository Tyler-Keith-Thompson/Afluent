//
//  DelaySequenceTests.swift
//
//
//  Created by Tyler Thompson on 12/8/23.
//

import Afluent
import AfluentTesting
import Atomics
import Clocks
import ConcurrencyExtras
import Foundation
import Testing

struct DelaySequenceTests {
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func delay_DelaysAllOutputByExpectedTime() async throws {
        // Create a simple AsyncSequence of integers
        let clock = TrackedTestClock()
        let upstreamFinished = ManagedAtomic(false)
        // Delay stamps each element with `clock.now` as the upstream produces it.
        let numbers = [1, 2, 3].async.handleEvents(receiveComplete: {
            upstreamFinished.store(true, ordering: .sequentiallyConsistent)
        })
        let delayDuration: Duration = .milliseconds(10)

        // Measure the time before starting the delayed sequence
        let startTime = clock.now

        // Create the delayed sequence
        let delayedNumbers = numbers.delay(for: delayDuration, clock: clock)

        let task = Task {
            // Iterate over the delayed sequence
            var count = 0
            for try await _ in delayedNumbers {
                count += 1
                let currentTime = clock.now
                let elapsedTime = startTime.duration(to: currentTime)

                // Check if the elapsed time is approximately equal to the expected delay
                #expect(elapsedTime >= delayDuration, "Element \(count) was not delayed correctly.")
            }
            return count
        }

        // Every element must be stamped at time zero and a sleep registered before time moves, otherwise
        // the deadlines land past the advance and the test hangs.
        try await wait(
            until: upstreamFinished.load(ordering: .sequentiallyConsistent),
            timeout: .seconds(2))
        try await clock.advance(by: delayDuration, whenSleeping: 1)

        let count = try await task.value
        // Ensure all elements were received
        #expect(count == 3, "Not all elements were received.")
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func delay_DoesNotDelayEveryElement() async throws {
        // Create a simple AsyncSequence of integers
        let clock = TrackedTestClock()
        let upstreamFinished = ManagedAtomic(false)
        // Delay stamps each element with `clock.now` as the upstream produces it.
        let numbers = [1, 2, 3].async.handleEvents(receiveComplete: {
            upstreamFinished.store(true, ordering: .sequentiallyConsistent)
        })
        let delayDuration: Duration = .milliseconds(10)

        // Measure the time before starting the delayed sequence
        let startTime = clock.now

        // Create the delayed sequence
        let delayedNumbers = numbers.delay(for: delayDuration, clock: clock)

        // Iterate over the delayed sequence
        let task = Task {
            var count = 0
            for try await _ in delayedNumbers {
                count += 1
                let currentTime = clock.now
                let elapsedTime = startTime.duration(to: currentTime)

                if count == 1 {
                    #expect(
                        elapsedTime >= delayDuration, "Element \(count) was not delayed correctly.")
                } else {
                    #expect(
                        elapsedTime < delayDuration * count,
                        "Element \(count) was not delayed correctly.")
                }
            }
            return count
        }

        // Every element must be stamped at time zero and a sleep registered before time moves, otherwise
        // the deadlines land past the advance and the test hangs.
        try await wait(
            until: upstreamFinished.load(ordering: .sequentiallyConsistent),
            timeout: .seconds(2))
        try await clock.advance(by: delayDuration, whenSleeping: 1)

        let count = try await task.value
        // Ensure all elements were received
        #expect(count == 3, "Not all elements were received.")
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func delay_DelaysCorrectlyEvenAfterIntervalHasPassed() async throws {
        let clock = TrackedTestClock()
        let delayDuration: Duration = .milliseconds(10)

        let (stream, continuation) = AsyncStream<Int>.makeStream()
        continuation.yield(1)

        let delayedNumbers = stream.delay(for: delayDuration, clock: clock)
        let startTime = clock.now
        let receivedCount = ManagedAtomic(0)

        let task = Task {
            var elapsed = [Duration]()
            for try await _ in delayedNumbers {
                elapsed.append(startTime.duration(to: clock.now))
                receivedCount.wrappingIncrement(ordering: .sequentiallyConsistent)
            }
            return elapsed
        }

        // Only the test moves time. Element 1 is delayed from 0 to 10.
        try await clock.advance(by: delayDuration, whenSleeping: 1)
        try await wait(
            until: receivedCount.load(ordering: .sequentiallyConsistent) == 1, timeout: .seconds(2))

        // 15 ms pass with nothing upstream; element 2 then arrives at 25 and is delayed to 35.
        await clock.advance(by: .milliseconds(15))
        continuation.yield(2)
        try await clock.advance(by: delayDuration, whenSleeping: 1)
        continuation.finish()

        let elapsed = try await task.value
        #expect(elapsed == [.milliseconds(10), .milliseconds(35)])
    }
}
