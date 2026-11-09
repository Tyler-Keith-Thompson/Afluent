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
        let testClock1 = TrackedTestClock()
        let testClock2 = TrackedTestClock()
        let unthrottledElementContainer = ElementContainer<TestClock<Duration>.Instant>()
        let throttledElementContainer = ElementContainer<TestClock<Duration>.Instant>()
        let upstreamRequests = ManagedAtomic(0)
        let task = Task {
            for try await instant in TimerSequence.publish(
                every: .seconds(3), clock: testClock1
            )
            .handleEvents(receiveOutput: {
                await unthrottledElementContainer.append($0)
            })
            .handleEvents(receiveNext: {
                upstreamRequests.wrappingIncrement(ordering: .sequentiallyConsistent)
            })
            .throttle(for: .seconds(10), clock: testClock2, latest: latest) {
                await throttledElementContainer.append(instant)
            }
        }

        // Combine emits at 3 s and then at the end of each 10 s window, in both modes.
        let emissionSeconds = [3, 13, 23, 33, 43, 53]
        // One second at a time, and only the test moves time. Combine runs both on one clock, so within a second:
        // - before the first emission the throttle is waiting for an element, and that element must be stamped
        //   with the new time, so the throttle clock moves first;
        // - after it the throttle is sleeping until its window ends, and an element arriving in the same second
        //   must be stored before the throttle wakes (at 33 s the latest element is 33, not 30), so the timer
        //   clock moves first.
        for second in 1...emissionSeconds.last! {
            let throttleIsSleeping = await !throttledElementContainer.elements.isEmpty
            if !throttleIsSleeping {
                await testClock2.advance(by: .seconds(1))
            }
            try await testClock1.advance(by: .seconds(1), whenSleeping: 1)
            let produced = second / 3
            // Throttle asks for the next upstream element only after it has stored the previous one.
            try await wait(
                until: await unthrottledElementContainer.elements.count == produced
                    && upstreamRequests.load(ordering: .sequentiallyConsistent) == produced + 1,
                timeout: .seconds(2))
            if throttleIsSleeping {
                try await testClock2.advance(by: .seconds(1), whenSleeping: 1)
            }
            let emitted = emissionSeconds.filter { $0 <= second }.count
            try await wait(
                until: await throttledElementContainer.elements.count == emitted,
                timeout: .seconds(2))
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
            let upstream = UpstreamProgress()
            let throttledStream = upstream.observe(stream).throttle(
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
                finished: finished,
                upstream: upstream)
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
            let upstream = UpstreamProgress()
            let throttledStream = upstream.observe(stream).throttle(
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
                finished: finished,
                upstream: upstream)
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
        upstream: UpstreamProgress,
        function: StaticString = #function
    ) async {
        #expect(
            streamInput.count == expectedOutput.count,
            """
            Input:  "\(streamInput)"
            Output: "\(expectedOutput)"
            """)

        let advancedDuration = ManagedAtomic<Int>(0)
        var yieldedValues = 0
        var upstreamTerminated = false

        steps: for (i, step) in streamInput.enumerated() {
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
                if !upstreamTerminated { yieldedValues += 1 }
            } else if step.lowercased() == "e" {
                continuation.yield(with: .failure(TestError.upstreamError))
                await Task.megaYield()
                upstreamTerminated = true
            } else if step == "|" {
                continuation.finish()
                await Task.megaYield()
                upstreamTerminated = true
            }

            // The consumer's output doesn't show whether the throttle has taken an input that produces no
            // output yet (for "123|-", the output stays "1" through "2", "3" and "|"). If the clock moves before
            // it does, the throttle can emit a staged element instead of the expected one, or instead of
            // finishing. So wait for the throttle's upstream task to catch up first. It stages each element
            // before asking for the next, so `yieldedValues + 1` requests means every value is staged. The end
            // of the upstream is seen as it is delivered, one actor call before the throttle records it.
            let expectedRequests = yieldedValues + (upstreamTerminated ? 0 : 1)
            let expectTerminated = upstreamTerminated
            do {
                try await wait(
                    until: upstream.requests.load(ordering: .sequentiallyConsistent)
                        >= expectedRequests
                        && upstream.terminated.load(ordering: .sequentiallyConsistent)
                            == expectTerminated,
                    timeout: .seconds(2))
                if upstreamTerminated { await Task.megaYield() }
            } catch {
                Issue.record(
                    "The throttle never took input step \(i) (\(step)) of test case \(testCase).")
                break steps
            }

            // At every element, assert correct elements
            let expectedOutputForStep = expectedOutput.prefix(i + 1)
            let expectedElements = expectedOutputForStep.compactMap { Int(String($0)) }
            let expectedMinimumDuration = max(expectedElements.count - 1, 0) * 10
            let expectError = expectedOutputForStep.contains("e")
            let expectFinish = expectedOutputForStep.contains("|")

            // `megaYield` alone doesn't guarantee the consumer has caught up: the throttle's chain of awaits can
            // need more scheduling rounds than it provides, especially under CPU load. If the consumer falls
            // behind, later upstream events overwrite values it hasn't consumed yet and the test fails spuriously.
            // So wait (bounded, in real time) for the expected state before asserting. If it never arrives, the
            // timeout is recorded, the expectations below show the mismatch, and the rest of the case is skipped,
            // so a regression costs one timeout rather than one per remaining step.
            let reachedExpectedState: Bool
            do {
                try await wait(
                    until: await test.elements == expectedElements
                        && errorThrown.load(ordering: .sequentiallyConsistent) == expectError
                        && finished.load(ordering: .sequentiallyConsistent) == expectFinish,
                    timeout: .seconds(2))
                reachedExpectedState = true
            } catch {
                // Record the timeout itself: the state may arrive just after it, so the checks below can pass
                // even though the rest of the case is about to be skipped.
                Issue.record("Timed out waiting for step \(i) (\(step)) of test case \(testCase).")
                reachedExpectedState = false
            }

            let elements = await test.elements
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
            guard reachedExpectedState else { break steps }
        }
        continuation.finish()
    }
}

/// Counts what the throttle's upstream task has asked for and been given.
private final class UpstreamProgress: Sendable {
    let requests = ManagedAtomic<Int>(0)
    let terminated = ManagedAtomic<Bool>(false)

    func observe<S: AsyncSequence & Sendable>(_ upstream: S) -> AsyncSequences.HandleEvents<S>
    where S.Element: Sendable {
        upstream.handleEvents(
            receiveNext: { [requests] in
                requests.wrappingIncrement(ordering: .sequentiallyConsistent)
            },
            receiveError: { [terminated] _ in
                terminated.store(true, ordering: .sequentiallyConsistent)
            },
            receiveComplete: { [terminated] in
                terminated.store(true, ordering: .sequentiallyConsistent)
            })
    }
}

private actor ElementContainer<V> {
    var elements = [V]()

    func append(_ element: V) {
        elements.append(element)
    }
}
