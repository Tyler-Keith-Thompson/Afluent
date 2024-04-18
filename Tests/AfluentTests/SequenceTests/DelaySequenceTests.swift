//
//  DelaySequenceTests.swift
//
//
//  Created by Tyler Thompson on 12/8/23.
//

import Afluent
import Clocks
import ConcurrencyExtras
import Foundation
import Testing

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct DelaySequenceTests {
    @Test func delay_DelaysAllOutputByExpectedTime() async throws {
        // Create a simple AsyncSequence of integers
        let clock = TestClock()
        let numbers = [1, 2, 3].async
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

        await clock.advance(by: delayDuration)

        let count = try await task.value
        // Ensure all elements were received
        #expect(count == 3, "Not all elements were received.")
    }

    @Test func delay_DoesNotDelayEveryElement() async throws {
        // Create a simple AsyncSequence of integers
        let clock = TestClock()
        let numbers = [1, 2, 3].async
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
                    #expect(elapsedTime >= delayDuration, "Element \(count) was not delayed correctly.")
                } else {
                    #expect(elapsedTime < delayDuration * count, "Element \(count) was not delayed correctly.")
                }
            }
            return count
        }

        await clock.advance(by: delayDuration)

        let count = try await task.value
        // Ensure all elements were received
        #expect(count == 3, "Not all elements were received.")
    }

    @Test func delay_DelaysCorrectlyEvenAfterIntervalHasPassed() async throws {
        await withMainSerialExecutor {
            let clock = TestClock()
            let delayDuration: Duration = .milliseconds(10)

            let (stream, continuation) = AsyncStream<Int>.makeStream()
            continuation.yield(1)

            let delayedNumbers = stream.delay(for: delayDuration, clock: clock)

            let startTime = clock.now

            // Iterate over the delayed sequence
            let task = Task {
                var count = 0
                for try await _ in delayedNumbers {
                    count += 1
                    let currentTime = clock.now
                    let elapsedTime = startTime.duration(to: currentTime)

                    if count == 1 {
                        #expect(elapsedTime >= delayDuration, "Element \(count) was not delayed correctly.")
                        await clock.advance(by: .milliseconds(15))
                        continuation.yield(2)
                        Task { await clock.advance(by: delayDuration) }
                    } else {
                        #expect(elapsedTime >= delayDuration + .milliseconds(15), "Element \(count) was not delayed correctly.")
                        continuation.finish()
                    }
                }
                return count
            }

            await clock.advance(by: delayDuration)

            _ = await task.result
        }
    }
}

extension Array {
    fileprivate var async: AsyncStream<Element> {
        AsyncStream { continuation in
            for element in self {
                continuation.yield(element)
            }
            continuation.finish()
        }
    }
}
