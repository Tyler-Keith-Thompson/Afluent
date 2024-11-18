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
        // * .   | Assert with no delay
        // * e   | Emit an error
        // OUTPUT LEGNED:
        // * 1-9 | Check for values 1 through 9
        // * -   | Append 10 milliseconds (the full throttle duration) to total time waited
        // * e   | Emit an error
        ("-", ""),
        ("1.", "1"),
        ("123.", "1"),
        ("123-", "13"),
        ("123e4-", "1e"),
        ("1-23-", "1-23"),
        ("1-23-e4-", "1-23-e"),
        ("123e-", "1e"),
        ("1-23456789-", "1-29"),
        ("1-2-3-4-5-6-7-8-9-", "1-2-3-4-5-6-7-8-9"),
        ("123-45-67-89-", "13-5-7-9"),
        ("1-2345`6789-", "1-2-9"),
        ("1``2``3``4``5``6``7``8``9``", "1-2-3-4-5-6-7-8-9"),
        ("12345--6789-", "15--69"),
        ("12345-67-89-", "15-7-9"),
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
            let errors = ElementContainer<Error>()
            let throttledStream = stream.throttle(
                for: .milliseconds(10), clock: testClock, latest: true)
            let task = Task {
                do {
                    for try await el in throttledStream {
                        await test.append(el)
                    }
                } catch {
                    await errors.append(error)
                }
            }
            let advancedDuration = ManagedAtomic<Int>(0)
            await parseThrottleDSL(
                testCase: testCase,
                streamInput: streamInput,
                expectedOutput: expectedOutput,
                testClock: testClock,
                advancedDuration: advancedDuration,
                continuation: continuation,
                test: test,
                errors: errors)
            task.cancel()
        }
    }

    static let latestFalseArguments: [(Int, String, String)] = [
        // INPUT LEGEND:
        // * 1-9 | Emit the values 1 through 9
        // * -   | Wait 10 milliseconds (the full throttle duration) and assert
        // * `   | Wait 5 milliseconds (half the throttle duration) and assert
        // * e   | Emit an error
        // OUTPUT LEGNED:
        // * 1-9 | Check for values 1 through 9
        // * -   | Append 10 milliseconds (the full throttle duration) to total time waited
        // * e   | Emit an error
        ("-", ""),
        ("1-", "1"),
        ("123.", "1"),
        ("123-", "12"),
        ("123e4-", "1e"),
        ("1-23-", "1-23"),
        ("1-23-e4-", "1-23-e"),
        ("123e-", "1e"),
        ("1-23456789-", "1-23"),
        ("1-2-3-4-5-6-7-8-9-", "1-2-3-4-5-6-7-8-9"),
        ("123-45-67-89-", "12-4-6-8"),
        ("1-2345`6789", "1-2-3"),
        ("1``2``3``4``5``6``7``8``9``", "1-2-3-4-5-6-7-8-9"),
        ("12345--6789-", "12--67"),
        ("12345-67-89-", "12-6-8"),
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
            let errors = ElementContainer<Error>()
            let throttledStream = stream.throttle(
                for: .milliseconds(10), clock: testClock, latest: false)
            let task = Task {
                do {
                    for try await el in throttledStream {
                        await test.append(el)
                    }
                } catch {
                    await errors.append(error)
                }
            }
            let advancedDuration = ManagedAtomic<Int>(0)
            await parseThrottleDSL(
                testCase: testCase,
                streamInput: streamInput,
                expectedOutput: expectedOutput,
                testClock: testClock,
                advancedDuration: advancedDuration,
                continuation: continuation,
                test: test,
                errors: errors)
            task.cancel()
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    fileprivate func parseThrottleDSL(
        testCase: Int,
        streamInput: String, expectedOutput: String, testClock: TestClock<Duration>,
        advancedDuration: ManagedAtomic<Int>,
        continuation: AsyncThrowingStream<Int, any Error>.Continuation,
        test: ElementContainer<Int>,
        errors: ElementContainer<Error>
    ) async {
        for (i, step) in streamInput.enumerated() {
            if step == "-" {
                await testClock.advance(by: .milliseconds(10))
                await Task.yield()
                advancedDuration.wrappingIncrement(by: 10, ordering: .sequentiallyConsistent)
            } else if step == "`" {
                await testClock.advance(by: .milliseconds(5))
                await Task.yield()
                advancedDuration.wrappingIncrement(by: 5, ordering: .sequentiallyConsistent)
            } else if let val = Int(String(step)) {
                continuation.yield(val)
            } else if step.lowercased() == "e" {
                continuation.yield(with: .failure(TestError.upstreamError))
            } else if step == "." {
                await Task.yield()
            }

            // At every halt point, assert correct elements
            if step == "-" || step == "`" || step == "." {
                _ = await Task {
                    await Task.yield()
                    let elements = await test.elements
                    // Parse the expected DSL, this is tricky because you have to sort of calculate how far in time to go to understand what the expected result is
                    let (total, expected, hasError) = expectedOutput.reduce(
                        into: (total: 0, expected: [Int](), hasError: false)
                    ) { partialResult, character in
                        guard
                            partialResult.total
                                < advancedDuration.load(ordering: .sequentiallyConsistent)
                        else {
                            return
                        }
                        if let element = Int(String(character)) {
                            partialResult.expected.append(element)
                        }
                        switch character {
                            case "-":
                                partialResult.total += 10
                            case "`":
                                partialResult.total += 5
                            case "e":
                                partialResult.hasError = true
                            default: break
                        }
                    }
                    let failureDebugMessage: Comment = """
                        test case: \(testCase)
                        i: \(i)
                        step: \(step)
                        duration: \(advancedDuration.load(ordering: .sequentiallyConsistent))
                        total: \(total)
                        """
                    #expect(elements == expected, failureDebugMessage)
                    if hasError {
                        #expect(await errors.elements.count == 1, failureDebugMessage)
                    }
                }.result
            }
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
