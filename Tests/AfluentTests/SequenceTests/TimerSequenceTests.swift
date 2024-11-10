//
//  TimerSequenceTests.swift
//  Afluent
//
//  Created by Annalise Mariottini on 11/9/24.
//

@_spi(Experimental) import Afluent
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
        #expect(actualOutput == expectedOutput)

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
        #expect(actualOutput1 == expectedOutput1)
        #expect(actualOutput2 == expectedOutput2)

        task1.cancel()
        task2.cancel()
    }

    // For this test case, we want to test infrequent demand that occurs off of the interval of the publisher
    // In this specific test, we have a publisher emitting every 0.01 seconds
    // But we only await the next value every 0.015 seconds
    // The first element emitted will be at 0.01, but every element after that will "skew" to the cadence of the demand
    // E.g. [0.01, 0.025, 0.04, 0.055, 0.07, 0.085, ...]
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(arguments: [10])
    func timerSequencePublishesOnInterval_whenNotContinuouslySubscribed(expectedCount: Int)
        async throws
    {
        try await withMainSerialExecutor {
            let testClock = TestClock()
            let testOutput = TestOutput()

            let skew = 1.5
            let skewAmount = skew - 1.0

            final class Wrapper<Iterator: AsyncIteratorProtocol>: @unchecked Sendable
            where Iterator.Element: Sendable {
                init(_ iterator: Iterator) {
                    self.iterator = iterator
                }
                var iterator: Iterator
                var nextCalled = PassthroughSubject<Void>()

                func next() async throws -> Iterator.Element? {
                    let task = Task {
                        try await iterator.next()
                    }
                    await Task.yield()
                    nextCalled.send()
                    return try await task.value
                }
            }

            let wrappedIterator = Wrapper(
                TimerSequence.publish(every: .milliseconds(10), clock: testClock)
                    .makeAsyncIterator())

            let task = Task {
                for _ in 0..<expectedCount {
                    if let output = try await wrappedIterator.next() {
                        await testOutput.append(output)
                        await testClock.advance(by: .milliseconds(10) * skew)
                    }
                }
            }

            try await wrappedIterator.nextCalled.first()
            await testClock.advance(by: .milliseconds(10) * skew)
            try await wait(
                until: await testOutput.output.count == expectedCount, timeout: .seconds(1))

            let expectedOutput: [TestClock<Duration>.Instant] = Array(1...expectedCount)
                .map {
                    switch $0 {
                        case 1:
                            return .init(offset: .milliseconds(10))
                        default:
                            let multiplier = Double($0) * skew
                            return .init(
                                offset: .milliseconds(10 * multiplier)
                                    - .milliseconds(10 * skewAmount))
                    }
                }
            let actualOutput = await testOutput.output
            print(actualOutput)
            #expect(actualOutput == expectedOutput)

            task.cancel()
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(arguments: 1...10)
    func timerSequencePublishesOnInterval_whenTimePassesBetweeIteratorCreationAndActualDemand(
        expectedCount: Int
    ) async throws {
        let testClock = TestClock()
        let testOutput = TestOutput()

        let sequence = TimerSequence.publish(every: .milliseconds(10), clock: testClock)

        let initialWaitIntervals = 5
        let clockAdvanced = SingleValueSubject<Void>()

        let task = Task {
            var iterator = sequence.makeAsyncIterator()
            await testClock.advance(by: .milliseconds(10) * initialWaitIntervals)
            try clockAdvanced.send()
            while let output = await iterator.next() {
                await testOutput.append(output)
            }
        }

        try await clockAdvanced.execute()
        // this wait should fail, since the time interval advance occurred _before_ next() was called
        await #expect(throws: TimeoutError.timedOut) {
            try await wait(
                until: await testOutput.output.count == initialWaitIntervals,
                timeout: .milliseconds(1))
        }
        // now we advance the clock to our expected count interval amount
        await testClock.advance(by: .milliseconds(10) * expectedCount)
        try await wait(
            until: await testOutput.output.count == expectedCount, timeout: .milliseconds(1))

        // since time advanced before demand, there will be some initial offset in the output
        let expectedOutput: [TestClock<Duration>.Instant] = Array(1...expectedCount)
            .map { $0 + initialWaitIntervals }
            .map { .init(offset: .milliseconds(10) * $0) }
        let actualOutput = await testOutput.output
        #expect(actualOutput == expectedOutput)

        task.cancel()
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
        #expect(actualOutput == expectedOutput)
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
