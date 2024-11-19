//
//  ThrottleSequenceTests.swift
//
//
//  Created by Trip Phillips on 2/12/24.
//

import Afluent
import AfluentTesting
import Atomics
import Clocks
import ConcurrencyExtras
import Foundation
import Testing

struct ThrottleSequenceTests {
    enum TestError: Error {
        case upstreamError
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func testThrottleChecksForCancellation_whenLatestIsTrue() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()

            let stream = AsyncStream<Int> { _ in }.throttle(
                for: .milliseconds(10), clock: testClock, latest: true)

            let task = Task {
                for try await _ in stream {}
            }

            task.cancel()

            let result = await task.result

            #expect(throws: CancellationError.self) { try result.get() }
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func throttleChecksForCancellation_whenLatestIsFalse() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()

            let stream = AsyncStream<Int> { _ in }.throttle(
                for: .milliseconds(10), clock: testClock, latest: false)

            let task = Task {
                for try await _ in stream {}
            }

            task.cancel()

            let result = await task.result

            #expect(throws: CancellationError.self) { try result.get() }
        }
    }

    //    cancellable = Timer.publish(every: 3.0, on: .main, in: .default)
    //        .autoconnect()
    //        .print("\(Date().description)")
    //        .throttle(for: 10.0, scheduler: RunLoop.main, latest: latest)
    //        .sink(
    //            receiveCompletion: { print ("Completion: \($0).") },
    //            receiveValue: { print("Received Timestamp \($0).") }
    //         )
    //
    //    latest = true
    //
    //    2024-11-18 15:32:00 +0000: receive value: (2024-11-18 15:32:03 +0000)
    //    Received Timestamp 2024-11-18 15:32:03 +0000.
    //    2024-11-18 15:32:00 +0000: receive value: (2024-11-18 15:32:06 +0000)
    //    2024-11-18 15:32:00 +0000: receive value: (2024-11-18 15:32:09 +0000)
    //    2024-11-18 15:32:00 +0000: receive value: (2024-11-18 15:32:12 +0000)
    //    Received Timestamp 2024-11-18 15:32:12 +0000.
    //    2024-11-18 15:32:00 +0000: receive value: (2024-11-18 15:32:15 +0000)
    //    2024-11-18 15:32:00 +0000: receive value: (2024-11-18 15:32:18 +0000)
    //    2024-11-18 15:32:00 +0000: receive value: (2024-11-18 15:32:21 +0000)
    //    Received Timestamp 2024-11-18 15:32:21 +0000.
    //    2024-11-18 15:32:00 +0000: receive value: (2024-11-18 15:32:24 +0000)
    //    2024-11-18 15:32:00 +0000: receive value: (2024-11-18 15:32:27 +0000)
    //    2024-11-18 15:32:00 +0000: receive value: (2024-11-18 15:32:30 +0000)
    //    2024-11-18 15:32:00 +0000: receive value: (2024-11-18 15:32:33 +0000)
    //    Received Timestamp 2024-11-18 15:32:33 +0000.
    //    2024-11-18 15:32:00 +0000: receive value: (2024-11-18 15:32:36 +0000)
    //    2024-11-18 15:32:00 +0000: receive value: (2024-11-18 15:32:39 +0000)
    //    2024-11-18 15:32:00 +0000: receive value: (2024-11-18 15:32:42 +0000)
    //    Received Timestamp 2024-11-18 15:32:42 +0000.
    //    2024-11-18 15:32:00 +0000: receive value: (2024-11-18 15:32:45 +0000)
    //    2024-11-18 15:32:00 +0000: receive value: (2024-11-18 15:32:48 +0000)
    //    2024-11-18 15:32:00 +0000: receive value: (2024-11-18 15:32:51 +0000)
    //    Received Timestamp 2024-11-18 15:32:51 +0000.
    //
    //    latest = false
    //
    //    2024-11-18 15:30:00 +0000: receive value: (2024-11-18 15:30:03 +0000)
    //    Received Timestamp 2024-11-18 15:30:03 +0000.
    //    2024-11-18 15:30:00 +0000: receive value: (2024-11-18 15:30:06 +0000)
    //    2024-11-18 15:30:00 +0000: receive value: (2024-11-18 15:30:09 +0000)
    //    2024-11-18 15:30:00 +0000: receive value: (2024-11-18 15:30:12 +0000)
    //    Received Timestamp 2024-11-18 15:30:06 +0000.
    //    2024-11-18 15:30:00 +0000: receive value: (2024-11-18 15:30:15 +0000)
    //    2024-11-18 15:30:00 +0000: receive value: (2024-11-18 15:30:18 +0000)
    //    2024-11-18 15:30:00 +0000: receive value: (2024-11-18 15:30:21 +0000)
    //    Received Timestamp 2024-11-18 15:30:15 +0000.
    //    2024-11-18 15:30:00 +0000: receive value: (2024-11-18 15:30:24 +0000)
    //    2024-11-18 15:30:00 +0000: receive value: (2024-11-18 15:30:27 +0000)
    //    2024-11-18 15:30:00 +0000: receive value: (2024-11-18 15:30:30 +0000)
    //    2024-11-18 15:30:00 +0000: receive value: (2024-11-18 15:30:33 +0000)
    //    Received Timestamp 2024-11-18 15:30:24 +0000.
    //    2024-11-18 15:30:00 +0000: receive value: (2024-11-18 15:30:36 +0000)
    //    2024-11-18 15:30:00 +0000: receive value: (2024-11-18 15:30:39 +0000)
    //    2024-11-18 15:30:00 +0000: receive value: (2024-11-18 15:30:42 +0000)
    //    Received Timestamp 2024-11-18 15:30:36 +0000.
    //    2024-11-18 15:30:00 +0000: receive value: (2024-11-18 15:30:45 +0000)
    //    2024-11-18 15:30:00 +0000: receive value: (2024-11-18 15:30:48 +0000)
    //    2024-11-18 15:30:00 +0000: receive value: (2024-11-18 15:30:51 +0000)
    //    Received Timestamp 2024-11-18 15:30:45 +0000.

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(arguments: [true, false])
    func throttleWithTimerPublisherReplicatesCombineBehavior(latest: Bool) async throws {
        try await withMainSerialExecutor {
            let testClock1 = TestClock()
            let testClock2 = TestClock()
            let unthrottledElementContainer = ElementContainer<TestClock<Duration>.Instant>()
            let throttledElementContainer = ElementContainer<TestClock<Duration>.Instant>()
            let task = try await Task.waitUntilExecutionStarted {
                for try await instant in TimerSequence.publish(
                    every: .seconds(3), clock: testClock1
                )
                .handleEvents(receiveOutput: {
                    await unthrottledElementContainer.append($0)
                })
                .throttle(for: .seconds(10), clock: testClock2, latest: latest) {
                    await throttledElementContainer.append(instant)
                }
            }

            while await throttledElementContainer.elements.count < 6 {
                async let _ = testClock1.advance(by: .seconds(1))
                async let _ = testClock2.advance(by: .seconds(1))
            }

            task.cancel()

            let unthrottledElements = await unthrottledElementContainer.elements
            let throttledElements = await throttledElementContainer.elements

            let expectedUnthrottledElements: [TestClock<Duration>.Instant] = Array(1...17)
                .map { $0 * 3 }
                .map { .init(offset: .seconds($0)) }
            let expectedThrottled = {
                // matches Combine values above
                if latest {
                    [3, 12, 21, 33, 42, 51]
                } else {
                    [3, 6, 15, 24, 36, 45]
                }
            }()
            let expectedThrottledElements: [TestClock<Duration>.Instant] =
                expectedThrottled
                .map { .init(offset: .seconds($0)) }

            #expect(unthrottledElements.count == 17)
            #expect(throttledElements.count == 6)
            #expect(unthrottledElements == expectedUnthrottledElements, "latest: \(latest)")
            #expect(throttledElements == expectedThrottledElements, "latest: \(latest)")
        }
    }

    static let latestTrueArguments: [(Int, String, String)] = [
        // INPUT LEGEND:
        // * 1-9 | Emit the values 1 through 9
        // * -   | Wait 10 milliseconds (the full throttle duration) and assert
        // * `   | Wait 5 milliseconds (half the throttle duration) and assert
        // * e   | Emit an error
        // * |   | Finish
        // OUTPUT LEGNED:
        // * 1-9 | Check for values 1 through 9
        // * e   | Check for an error
        // * |   | Check for finish
        // * ' ' | No new elements at that step
        // Validation:
        // - Each step is validated
        // - Alignment indicates what values should be present at the validation step
        (
            "-|",
            " |"
        ),
        (
            "1-|",
            "1 |"
        ),
        (
            "123|-",
            "1   |"
        ),
        (
            "123-|-",
            "1  3 |"
        ),
        (
            "123e4-",
            "1    e"
        ),
        (
            "1-23-|-",
            "1 2 3 |"
        ),
        (
            "1-23-e4-",
            "1 2 3  e"
        ),
        (
            "123e-",
            "1   e"
        ),
        (
            "1-23456789--|",
            "1 2       9 |"
        ),
        (
            "1-2-3-4-5-6-7-8-9-|",
            "1 2 3 4 5 6 7 8 9-|"
        ),
        (
            "123-45-67-89--|",
            "1  3  5  7  9 |"
        ),
        (
            "1-2345`6789--|",
            "1 2        9 |"
        ),
        (
            "1``2``3``4``5``6``7``8``9``|",
            "1  2  3  4  5  6  7  8  9``|"
        ),
        (
            "12345--6789--|",
            "1    5 6   9 |"
        ),
        (
            "12345-67-89--|",
            "1    5  7  9 |"
        ),
        (
            "123-456|-",
            "1  3    |"
        ),
        (
            "---1----2|-",
            "   1    2 |"
        ),
    ].enumerated().map { ($0.offset, $0.element.0, $0.element.1) }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.serialized, arguments: Self.latestTrueArguments)
    func throttleWithLatestTrue(testCase: Int, streamInput: String, expectedOutput: String)
        async throws
    {
        await withMainSerialExecutor {
            let (stream, continuation) = AsyncThrowingStream<Int, any Error>.makeStream()
            let testClock = TestClock()
            let test = ElementContainer<Int>()
            let errorThrown = ManagedAtomic<Bool>(false)
            let finished = ManagedAtomic<Bool>(false)
            let throttledStream = stream.throttle(
                for: .milliseconds(10), clock: testClock, latest: true)
            let task = Task {
                do {
                    for try await el in throttledStream {
                        await test.append(el)
                    }
                    finished.store(true, ordering: .sequentiallyConsistent)
                } catch {
                    errorThrown.store(true, ordering: .sequentiallyConsistent)
                }
            }
            await parseThrottleDSL(
                testCase: testCase,
                streamInput: streamInput,
                expectedOutput: expectedOutput,
                testClock: testClock,
                continuation: continuation,
                test: test,
                errorThrown: errorThrown,
                finished: finished)
            task.cancel()
        }
    }

    static let latestFalseArguments: [(Int, String, String)] = [
        // INPUT LEGEND:
        // * 1-9 | Emit the values 1 through 9
        // * -   | Wait 10 milliseconds (the full throttle duration) and assert
        // * `   | Wait 5 milliseconds (half the throttle duration) and assert
        // * e   | Emit an error
        // * |   | Finish
        // OUTPUT LEGNED:
        // * 1-9 | Check for values 1 through 9
        // * e   | Check for an error
        // * |   | Check for finish
        // * ' ' | No new elements at that step
        // Validation:
        // - Each step is validated
        // - Alignment indicates what values should be present at the validation step
        (
            "-|",
            " |"
        ),
        (
            "1-|",
            "1 |"
        ),
        (
            "123|-",
            "1   |"
        ),
        (
            "123-|-",
            "1  2 |"
        ),
        (
            "123e4-",
            "1    e"
        ),
        (
            "1-23-|-",
            "1-2 3 |"
        ),
        (
            "1-23-e4-",
            "1-2 3  e"
        ),
        (
            "123e-",
            "1   e"
        ),
        (
            "1-23456789--|",
            "1 2       3 |"
        ),
        (
            "1-2-3-4-5-6-7-8-9-|",
            "1 2 3 4 5 6 7 8 9 |"
        ),
        (
            "123-45-67-89--|",
            "1  2  4  6  8 |"
        ),
        (
            "1-2345`6789--|",
            "1 2        3 |"
        ),
        (
            "1``2``3``4``5``6``7``8``9``|",
            "1  2  3  4  5  6  7  8  9  |"
        ),
        (
            "12345--6789--|",
            "1    2 6   7 |"
        ),
        (
            "12345-67-89--|",
            "1    2  6  8 |"
        ),
        (
            "123-456|-",
            "1  2    |"
        ),
        (
            "---1----2|-",
            "   1    2 |"
        ),
    ].enumerated().map { ($0.offset, $0.element.0, $0.element.1) }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.serialized, arguments: Self.latestFalseArguments)
    func throttleWithLatestFalse(testCase: Int, streamInput: String, expectedOutput: String)
        async throws
    {
        await withMainSerialExecutor {
            let (stream, continuation) = AsyncThrowingStream<Int, any Error>.makeStream()
            let testClock = TestClock()
            let test = ElementContainer<Int>()
            let errorThrown = ManagedAtomic<Bool>(false)
            let finished = ManagedAtomic<Bool>(false)
            let throttledStream = stream.throttle(
                for: .milliseconds(10), clock: testClock, latest: false)
            let task = Task {
                do {
                    for try await el in throttledStream {
                        await test.append(el)
                    }
                    finished.store(true, ordering: .sequentiallyConsistent)
                } catch {
                    errorThrown.store(true, ordering: .sequentiallyConsistent)
                }
            }
            await parseThrottleDSL(
                testCase: testCase,
                streamInput: streamInput,
                expectedOutput: expectedOutput,
                testClock: testClock,
                continuation: continuation,
                test: test,
                errorThrown: errorThrown,
                finished: finished)
            task.cancel()
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    fileprivate func parseThrottleDSL(
        testCase: Int,
        streamInput: String, expectedOutput: String, testClock: TestClock<Duration>,
        continuation: AsyncThrowingStream<Int, any Error>.Continuation,
        test: ElementContainer<Int>,
        errorThrown: ManagedAtomic<Bool>,
        finished: ManagedAtomic<Bool>,
        function: StaticString = #function
    ) async {
        #expect(
            streamInput.count == expectedOutput.count,
            """
            Input:  "\(streamInput)"
            Output: "\(expectedOutput)"
            """)

        let advancedDuration = ManagedAtomic<Int>(0)

        for (i, step) in streamInput.enumerated() {
            if step == "-" {
                await testClock.advance(by: .milliseconds(10))
                await Task.megaYield()
                advancedDuration.wrappingIncrement(by: 10, ordering: .sequentiallyConsistent)
            } else if step == "`" {
                await testClock.advance(by: .milliseconds(5))
                await Task.megaYield()
                advancedDuration.wrappingIncrement(by: 5, ordering: .sequentiallyConsistent)
            } else if let val = Int(String(step)) {
                continuation.yield(val)
                await Task.megaYield()
            } else if step.lowercased() == "e" {
                continuation.yield(with: .failure(TestError.upstreamError))
                await Task.megaYield()
            } else if step == "|" {
                continuation.finish()
                await Task.megaYield()
            }

            // At every element, assert correct elements
            let elements = await test.elements
            let expectedOutputForStep = expectedOutput.prefix(i + 1)
            let expectedElements = expectedOutputForStep.compactMap { Int(String($0)) }
            let expectedMinimumDuration = max(expectedElements.count - 1, 0) * 10
            let expectError = expectedOutputForStep.contains("e")
            let expectFinish = expectedOutputForStep.contains("|")
            lazy var failureDebugMessage: Comment = """
                function: \(function)
                test case: \(testCase)
                i: \(i)
                step: \(step)
                """
            #expect(elements == expectedElements, failureDebugMessage)
            let duration = advancedDuration.load(ordering: .sequentiallyConsistent)
            #expect(duration >= expectedMinimumDuration, failureDebugMessage)
            let receivedError = errorThrown.load(ordering: .sequentiallyConsistent)
            #expect(receivedError == expectError, failureDebugMessage)
            let receivedFinish = finished.load(ordering: .sequentiallyConsistent)
            #expect(receivedFinish == expectFinish, failureDebugMessage)
        }
        continuation.finish()
    }
}

private actor ElementContainer<V> {
    var elements = [V]()

    func append(_ element: V) {
        elements.append(element)
    }
}
