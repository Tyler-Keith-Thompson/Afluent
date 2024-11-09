//
//  TimerSequenceTests.swift
//  Afluent
//
//  Created by Annalise Mariottini on 11/9/24.
//

import Afluent
import Atomics
import Clocks
import ConcurrencyExtras
import Foundation
import Testing

struct TimerSequenceTests {
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(arguments: 1...10)
    func timerSequencePublishesOnInterval(expectedCount: Int) async throws {
        let testClock = TestClock()
        let testOutput = TestOutput()

        let task = Task {
            for try await output in TimerSequence.publish(
                every: .milliseconds(10), clock: testClock)
            {
                await testOutput.append(output)
            }
        }

        await testClock.advance(by: .milliseconds(10) * expectedCount)

        try await wait(
            until: await testOutput.output.count == expectedCount, timeout: .milliseconds(1))

        let expectedOutput: [TestClock<Duration>.Instant] = Array(1...expectedCount).map {
            .init(offset: .milliseconds(10) * $0)
        }
        let actualOutput = await testOutput.output
        #expect(actualOutput == expectedOutput, "Unexpected output \(actualOutput)")

        task.cancel()
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(arguments: 2...10)
    func timerSequencePublishesOnInterval_withMultipleIterators(expectedCount: Int) async throws {
        let testClock = TestClock()
        let testOutput1 = TestOutput()
        let testOutput2 = TestOutput()

        let sequence = TimerSequence.publish(every: .milliseconds(10), clock: testClock)

        let task1 = Task {
            for try await output in sequence {
                await testOutput1.append(output)
            }
        }

        await testClock.advance(by: .milliseconds(10))
        try await wait(until: await testOutput1.output.count == 1, timeout: .milliseconds(1))

        let task2 = Task {
            for try await output in sequence {
                await testOutput2.append(output)
            }
        }

        await testClock.advance(by: .milliseconds(10) * (expectedCount - 1))

        try await wait(
            until: await testOutput1.output.count == expectedCount, timeout: .milliseconds(1))

        let expectedOutput1: [TestClock<Duration>.Instant] = Array(1...expectedCount).map {
            .init(offset: .milliseconds(10) * $0)
        }
        // the second sequence subscribed after the 1st value was already published
        let expectedOutput2: [TestClock<Duration>.Instant] = Array(2...expectedCount).map {
            .init(offset: .milliseconds(10) * $0)
        }
        let actualOutput1 = await testOutput1.output
        let actualOutput2 = await testOutput2.output
        #expect(actualOutput1 == expectedOutput1, "Unexpected output \(actualOutput1)")
        #expect(actualOutput2 == expectedOutput2, "Unexpected output \(actualOutput2)")

        task1.cancel()
        task2.cancel()
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func timerSequenceProperlyCancels() async throws {
        let testClock = TestClock()
        let testOutput = TestOutput()

        let taskCancelledSubject = SingleValueSubject<Void>()

        let task = Task {
            var iterator = TimerSequence.publish(every: .milliseconds(10), clock: testClock)
                .makeAsyncIterator()

            let instant1 = try #require(await iterator.next())
            await testOutput.append(instant1)

            // this would throw, since we're cancelled
            try? await taskCancelledSubject.execute()

            let instant2 = await iterator.next()
            #expect(instant2 == nil)
        }

        await testClock.advance(by: .milliseconds(10))
        try await wait(until: await testOutput.output.count == 1, timeout: .seconds(1))
        task.cancel()
        try taskCancelledSubject.send()
        try await task.value

        let expectedOutput: [TestClock<Duration>.Instant] = [
            .init(offset: .milliseconds(10))
        ]
        let actualOutput = await testOutput.output
        #expect(actualOutput == expectedOutput, "Unexpected output \(actualOutput)")
    }
}

private actor TestOutput<Value> {
    init(_ type: Value.Type) {
        self.output = []
    }

    var output: [Value]

    func append(_ instant: Value) {
        self.output.append(instant)
    }
}

extension TestOutput where Value == TestClock<Duration>.Instant {
    init() {
        self.init(Value.self)
    }
}
