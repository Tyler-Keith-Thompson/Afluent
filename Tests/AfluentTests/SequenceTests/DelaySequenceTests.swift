//
//  DelaySequenceTests.swift
//
//
//  Created by Tyler Thompson on 12/8/23.
//

import Foundation
import Afluent
import XCTest
import ConcurrencyExtras

final class DelaySequenceTests: XCTestCase {
    
    override func invokeTest() {
        withMainSerialExecutor {
            super.invokeTest()
        }
    }
    
    func testDelay_DelaysAllOutputByExpectedTime() async throws {
        // Create a simple AsyncSequence of integers
        let numbers = [1, 2, 3].async
        let delayDuration = Measurement(value: 10, unit: UnitDuration.milliseconds)

        // Measure the time before starting the delayed sequence
        let startTime = Date()

        // Create the delayed sequence
        let delayedNumbers = numbers.delay(for: delayDuration)

        // Iterate over the delayed sequence
        var count = 0
        for try await _ in delayedNumbers {
            count += 1
            let currentTime = Date()
            let elapsedTime = currentTime.timeIntervalSince(startTime)

            // Check if the elapsed time is approximately equal to the expected delay
            let expectedDelay = delayDuration.converted(to: .seconds).value
            XCTAssertGreaterThan(elapsedTime, expectedDelay, "Element \(count) was not delayed correctly.")
        }

        // Ensure all elements were received
        XCTAssertEqual(count, 3, "Not all elements were received.")
    }
    
    func testDelay_DoesNotDelayEveryElement() async throws {
        // Create a simple AsyncSequence of integers
        let numbers = [1, 2, 3].async
        let delayDuration = Measurement(value: 10, unit: UnitDuration.milliseconds)

        // Measure the time before starting the delayed sequence
        let startTime = Date()

        // Create the delayed sequence
        let delayedNumbers = numbers.delay(for: delayDuration)

        // Iterate over the delayed sequence
        var count = 0
        for try await _ in delayedNumbers {
            count += 1
            let currentTime = Date()
            let elapsedTime = currentTime.timeIntervalSince(startTime)

            if count == 1 {
                let expectedDelay = delayDuration.converted(to: .seconds).value
                XCTAssertGreaterThan(elapsedTime, expectedDelay, "Element \(count) was not delayed correctly.")
            } else {
                let expectedDelay = delayDuration.converted(to: .seconds).value * Double(count)
                XCTAssertLessThan(elapsedTime, expectedDelay, "Element \(count) was not delayed correctly.")
            }
        }

        // Ensure all elements were received
        XCTAssertEqual(count, 3, "Not all elements were received.")
    }
    
    func testDelay_DelaysCorrectlyEvenAfterIntervalHasPassed() async throws {
        let (stream, continuation) = AsyncStream<Int>.makeStream()

        let delayedNumbers = stream.delay(for: .milliseconds(10))

        DeferredTask { continuation.yield(1) }
            .delay(for: .milliseconds(15))
            .map { continuation.yield(2); continuation.finish() }
            .run()
        
        let startTime = Date()

        // Iterate over the delayed sequence
        var count = 0
        for try await _ in delayedNumbers {
            count += 1
            let currentTime = Date()
            let elapsedTime = currentTime.timeIntervalSince(startTime)

            if count == 1 {
                let expectedDelay = Measurement<UnitDuration>.milliseconds(10).converted(to: .seconds).value
                XCTAssertGreaterThan(elapsedTime, expectedDelay, "Element \(count) was not delayed correctly.")
            } else {
                let expectedDelay = Measurement<UnitDuration>.milliseconds(15 + 10).converted(to: .seconds).value
                XCTAssertGreaterThan(elapsedTime, expectedDelay, "Element \(count) was not delayed correctly.")
            }
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
