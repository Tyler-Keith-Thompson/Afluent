//
//  ThrottleSequenceTests.swift
//
//
//  Created by Trip Phillips on 2/12/24.
//

import Afluent
import Clocks
import ConcurrencyExtras
import Foundation
import Testing

@available(iOS 16.0, *)
struct ThrottleSequenceTests {
    enum TestError: Error {
        case upstreamError
    }

    actor ElementContainer {
        var elements = [Int]()

        func append(_ element: Int) {
            elements.append(element)
        }
    }

    @Test func testThrottleChecksForCancellation_whenLatestIsTrue() async throws {
        let testClock = TestClock()

        let stream = AsyncStream<Int> { continuation in
            continuation.finish()
        }.throttle(for: .milliseconds(10), clock: testClock, latest: true)

        let task = Task {
            for try await _ in stream { }
        }

        task.cancel()

        let result = await task.result

        #expect(throws: CancellationError.self) { try result.get() }
    }

    @Test func throttleChecksForCancellation_whenLatestIsFalse() async throws {
        let testClock = TestClock()

        let stream = AsyncStream<Int> { continuation in
            continuation.finish()
        }.throttle(for: .milliseconds(10), clock: testClock, latest: false)

        let task = Task {
            for try await _ in stream { }
        }

        task.cancel()

        let result = await task.result

        #expect(throws: CancellationError.self) { try result.get() }
    }

    @Test func throttleWithNoElements_returnsEmpty_andLatestIsTrue() async throws {
        let testClock = TestClock()

        let stream = AsyncStream<Int> { continuation in
            continuation.finish()
        }.throttle(for: .milliseconds(10), clock: testClock, latest: true)

        let elements = try await stream.collect().first()
        try #expect(#require(elements).isEmpty)
    }

    @Test func throttleWithNoElements_returnsEmpty_andLatestIsFalse() async throws {
        let testClock = TestClock()

        let stream = AsyncStream<Int> { continuation in
            continuation.finish()
        }.throttle(for: .milliseconds(10), clock: testClock, latest: false)

        let elements = try await stream.collect().first()
        try #expect(#require(elements).isEmpty)
    }

    @Test func throttleWithOneElement_returnsOneElement_andLatestIsTrue() async throws {
        let testClock = TestClock()

        let stream = AsyncStream<Int> { continuation in
            continuation.yield(1)
            continuation.finish()
        }.throttle(for: .milliseconds(10), clock: testClock, latest: true)

        let elements = try await stream.collect().first()
        #expect(elements == [1])
    }

    @Test func throttleWithOneElement_returnsOneElement_andLatestIsFalse() async throws {
        let testClock = TestClock()

        let stream = AsyncStream<Int> { continuation in
            continuation.yield(1)
            continuation.finish()
        }.throttle(for: .milliseconds(10), clock: testClock, latest: false)

        let elements = try await stream.collect().first()
        #expect(elements == [1])
    }

    @Test func throttleReturnsFirstAndLatestElementImmediately_whenReceivingMultipleElementsAtOnceAndStreamEnds_andLatestIsTrue() async throws {
        try await withMainSerialExecutor {
            let testClock = TestClock()

            let stream = AsyncStream { continuation in
                DeferredTask {
                    continuation.yield(1)
                    continuation.yield(2)
                    continuation.yield(3)
                    continuation.yield(4)
                    continuation.yield(5)
                    continuation.yield(6)
                    continuation.yield(7)
                    continuation.yield(8)
                    continuation.yield(9)
                    continuation.yield(10)
                    continuation.finish()
                }.run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: true)

            let elements = try await stream.collect().first()
            #expect(elements == [1, 10])
        }
    }

    @Test func throttleReturnsFirstAndSecondElementImmediately_whenReceivingMultipleElementsAtOnceAndStreamEnds_andLatestIsFalse() async throws {
        try await withMainSerialExecutor {
            let testClock = TestClock()

            let stream = AsyncStream { continuation in
                DeferredTask {
                    continuation.yield(1)
                    continuation.yield(2)
                    continuation.yield(3)
                    continuation.yield(4)
                    continuation.yield(5)
                    continuation.yield(6)
                    continuation.yield(7)
                    continuation.yield(8)
                    continuation.yield(9)
                    continuation.yield(10)
                    continuation.finish()
                }.run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)

            let elements = try await stream.collect().first()
            #expect(elements == [1, 2])
        }
    }

    @Test func throttleReturnsLatestElementInIntervalBeforeErrorInStream_whenLatestIsTrue() async throws {
        try await withMainSerialExecutor {
            let testClock = TestClock()

            let stream = AsyncThrowingStream { continuation in
                continuation.yield(1)
                continuation.yield(2)
                continuation.yield(3)
                continuation.yield(with: .failure(TestError.upstreamError))
                continuation.yield(4)
                continuation.finish()
            }
            .throttle(for: .milliseconds(10), clock: testClock, latest: true)
            .replaceError(with: -1)

            let elements = try await stream.collect().first()?.filter { $0 >= 0 }
            #expect(elements == [1, 3])
        }
    }

    @Test func throttleReturnsFirstElementInIntervalBeforeErrorInStream_whenLatestIsFalse() async throws {
        try await withMainSerialExecutor {
            let testClock = TestClock()

            let stream = AsyncThrowingStream { continuation in
                continuation.yield(1)
                continuation.yield(2)
                continuation.yield(3)
                continuation.yield(with: .failure(TestError.upstreamError))
                continuation.yield(4)
                continuation.finish()
            }
            .throttle(for: .milliseconds(10), clock: testClock, latest: false)
            .replaceError(with: -1)

            let elements = try await stream.collect().first()?.filter { $0 >= 0 }
            #expect(elements == [1, 2])
        }
    }

//    "1-2345`6789"
//    func testThrottleOnlyReturnsLatestElement_whenMultipleElementsAreReceivedAfterMultipleThrottleIntervalsHavePassed_10ms_andLatestIsTrue() async throws {
//    //        await withMainSerialExecutor {
//    //            let testClock = TestClock()
//    //            let elementContainer = ElementContainer()
//    //
//    //            let stream = AsyncStream { continuation in
//    //                DeferredTask {
//    //                    continuation.yield(1)
//    //                }
//    //                .delayThenHandleOutput(for: .milliseconds(100), testClock: testClock) { _ in
//    //                    continuation.yield(2)
//    //                    continuation.yield(3)
//    //                    continuation.yield(4)
//    //                    continuation.yield(6)
//    //
//    //                    await testClock.advance(by: .milliseconds(5))
//    //
//    //                    let elements = await elementContainer.elements
//    //                    XCTAssertEqual(elements, [1])
//    //
//    //                    continuation.yield(7)
//    //                    continuation.yield(8)
//    //                    continuation.yield(9)
//    //                    continuation.yield(10)
//    //
//    //                    await testClock.advance(by: .milliseconds(5))
//    //
//    //                    let elements2 = await elementContainer.elements
//    //                    XCTAssertEqual(elements2, [1, 10])
//    //
//    //                    continuation.finish()
//    //
//    //                    let elements3 = await elementContainer.elements
//    //                    XCTAssertEqual(elements3, [1, 10])
//    //                }
//    //                .run()
//    //            }.throttle(for: .milliseconds(10), clock: testClock, latest: true)
//    //
//    //            let task = Task {
//    //                for try await element in stream {
//    //                    await elementContainer.append(element)
//    //                }
//    //            }
//    //
//    //            _ = await task.result
//    //
//    //            let elements = await elementContainer.elements
//    //            XCTAssertEqual(elements, [1, 10])
//    //        }
//    //    }
    @Test(arguments: [
        ("1-23-e4", "1-3"),
        ("123e", "1-3"),
        ("1-23456789", "1-9"),
        ("1-2-3-4-5-6-7-8-9", "1-2-3-4-5-6-7-8-9"),
        ("123-45-67-89", "13-5-7-9"),
    ])
    func throttleWithLatestTrue(streamInput: String, expectedOutput: String) async throws {
        await withMainSerialExecutor {
            actor Test {
                var elements = [Int]()

                func append(_ element: Int) {
                    elements.append(element)
                }
            }

            let streamSteps = streamInput.components(separatedBy: "-")
            let outputSteps = expectedOutput.components(separatedBy: "-")
            let (stream, continuation) = AsyncThrowingStream<Int, any Error>.makeStream()
            let testClock = TestClock()
            let test = Test()
            let throttledStream = stream.throttle(for: .milliseconds(10), clock: testClock, latest: true)
            Task {
                for try await el in throttledStream {
                    await test.append(el)
                }
            }
            for (i, step) in streamSteps.enumerated() {
                for item in step {
                    if let val = Int(String(item)) {
                        continuation.yield(val)
                    } else if item.lowercased() == "e" {
                        continuation.yield(with: .failure(TestError.upstreamError))
                    }
                }

                _ = await Task {
                    let elements = await test.elements
                    let expected = outputSteps.prefix(i).flatMap { $0.compactMap { Int(String($0)) } }
                    #expect(elements == expected)
                }.result

                await testClock.advance(by: .milliseconds(10))
            }
            continuation.finish()
        }
    }

//    func testThrottleReturnsFirstElementInIntervalBeforeErrorInStreamWithDelay_whenLatestIsFalse() async {
//        await withMainSerialExecutor {
//            let testClock = TestClock()
//            let elementContainer = ElementContainer()
//
//            let stream = AsyncThrowingStream { continuation in
//                DeferredTask {
//                    continuation.yield(1)
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1])
//
//                    continuation.yield(2)
//                    continuation.yield(3)
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2])
//
//                    continuation.yield(with: .failure(TestError.upstreamError))
//                    continuation.yield(4)
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2])
//
//                    continuation.finish()
//                }
//                .run()
//            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
//
//            let task = Task {
//                do {
//                    for try await element in stream {
//                        await elementContainer.append(element)
//                    }
//                } catch {
//                    XCTAssertNotNil(error as? TestError)
//                }
//            }
//
//            _ = await task.result
//
//            let elements = await elementContainer.elements
//            XCTAssertEqual(elements, [1, 2])
//        }
//    }
//
//    func testThrottleReturnsFirstElementInIntervalThatCompletesThrowingError_whenLatestIsFalse() async {
//        await withMainSerialExecutor {
//            let testClock = TestClock()
//            let elementContainer = ElementContainer()
//
//            let stream = AsyncThrowingStream { continuation in
//                continuation.yield(1)
//                continuation.yield(2)
//                continuation.yield(3)
//                continuation.finish(throwing: TestError.upstreamError)
//            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
//
//            let task = Task {
//                do {
//                    for try await element in stream {
//                        await elementContainer.append(element)
//                    }
//                } catch {
//                    XCTAssertNotNil(error as? TestError)
//                }
//            }
//
//            _ = await task.result
//
//            let elements = await elementContainer.elements
//            XCTAssertEqual(elements, [1, 2])
//        }
//    }
//
//    func testThrottleOnlyThrottlesAfterFirstElementIsReceived_whenLatestIsFalse() async {
//        await withMainSerialExecutor {
//            let testClock = TestClock()
//            let elementContainer = ElementContainer()
//
//            let stream = AsyncThrowingStream { continuation in
//                DeferredTask {
//                    continuation.yield(1)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(2)
//                    continuation.yield(3)
//                    continuation.yield(4)
//                    continuation.yield(5)
//                    continuation.yield(6)
//                    continuation.yield(7)
//                    continuation.yield(8)
//                    continuation.yield(9)
//                    continuation.yield(10)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2])
//
//                    continuation.finish()
//
//                    let elements3 = await elementContainer.elements
//                    XCTAssertEqual(elements3, [1, 2])
//                }
//                .run()
//            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
//
//            let task = Task {
//                do {
//                    for try await element in stream {
//                        await elementContainer.append(element)
//                    }
//                } catch {
//                    XCTAssertNotNil(error as? TestError)
//                }
//            }
//
//            _ = await task.result
//
//            let elements = await elementContainer.elements
//            XCTAssertEqual(elements, [1, 2])
//        }
//    }
//
//
//
//    func testThrottleReturnsAllElements_whenOnlyOneElementIsReceivedDuringEachThrottleInterval_10ms_andLatestIsFalse() async throws {
//        await withMainSerialExecutor {
//            let testClock = TestClock()
//            let elementContainer = ElementContainer()
//
//            let stream = AsyncStream { continuation in
//
//                DeferredTask {
//                    continuation.yield(1)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(2)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//
//                    XCTAssertEqual(elements2, [1, 2])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(3)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//
//                    XCTAssertEqual(elements2, [1, 2, 3])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(4)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//
//                    XCTAssertEqual(elements2, [1, 2, 3, 4])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(5)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3, 4])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(6)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3, 4, 5])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5, 6])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(7)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3, 4, 5, 6])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5, 6, 7])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(8)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3, 4, 5, 6, 7])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5, 6, 7, 8])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(9)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3, 4, 5, 6, 7, 8])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5, 6, 7, 8, 9])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(10)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3, 4, 5, 6, 7, 8, 9])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
//
//                    continuation.finish()
//
//                    let elements3 = await elementContainer.elements
//                    XCTAssertEqual(elements3, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
//                }
//                .run()
//            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
//
//            let task = Task {
//                for try await element in stream {
//                    await elementContainer.append(element)
//                }
//            }
//
//            _ = await task.result
//
//            let elements = await elementContainer.elements
//            XCTAssertEqual(elements, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
//        }
//    }
//
//
//    func testThrottleOnlyReturnsFirstElementInInterval_whenMultipleElementsAreReceivedDuringEachThrottleInterval_10ms_andLatestIsFalse() async throws {
//        await withMainSerialExecutor {
//            let testClock = TestClock()
//            let elementContainer = ElementContainer()
//
//            let stream = AsyncStream { continuation in
//                DeferredTask {
//                    continuation.yield(1)
//                    continuation.yield(2)
//                    continuation.yield(3)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//                    continuation.yield(4)
//                    continuation.yield(5)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 4])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//                    continuation.yield(6)
//                    continuation.yield(7)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 4])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 4, 6])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//                    continuation.yield(8)
//                    continuation.yield(9)
//                    continuation.yield(10)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 4, 6])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 4, 6, 8])
//
//                    continuation.finish()
//
//                    let elements3 = await elementContainer.elements
//                    XCTAssertEqual(elements3, [1, 2, 4, 6, 8])
//                }
//                .run()
//            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
//
//            let task = Task {
//                for try await element in stream {
//                    await elementContainer.append(element)
//                }
//            }
//
//            _ = await task.result
//
//            let elements = await elementContainer.elements
//            XCTAssertEqual(elements, [1, 2, 4, 6, 8])
//        }
//    }
//
//

//
//    func testThrottleOnlyReturnsLatestElement_whenMultipleElementsAreReceivedAfterMultipleThrottleIntervalsHavePassed_10ms_andLatestIsFalse() async throws {
//        await withMainSerialExecutor {
//            let testClock = TestClock()
//            let elementContainer = ElementContainer()
//
//            let stream = AsyncStream { continuation in
//                DeferredTask {
//                    continuation.yield(1)
//                }
//                .delayThenHandleOutput(for: .milliseconds(100), testClock: testClock) { _ in
//                    continuation.yield(2)
//                    continuation.yield(3)
//                    continuation.yield(4)
//                    continuation.yield(6)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1])
//
//                    continuation.yield(7)
//                    continuation.yield(8)
//                    continuation.yield(9)
//                    continuation.yield(10)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2])
//
//                    continuation.finish()
//
//                    let elements3 = await elementContainer.elements
//                    XCTAssertEqual(elements3, [1, 2])
//                }
//                .run()
//            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
//
//            let task = Task {
//                for try await element in stream {
//                    await elementContainer.append(element)
//                }
//            }
//
//            _ = await task.result
//
//            let elements = await elementContainer.elements
//            XCTAssertEqual(elements, [1, 2])
//        }
//    }
//
//    func testThrottleOnlyReturnsLatestElement_afterMultipleThrottleIntervalsHavePassed_10ms_andLatestIsTrue() async throws {
//        await withMainSerialExecutor {
//            let testClock = TestClock()
//            let elementContainer = ElementContainer()
//
//            let stream = AsyncStream { continuation in
//
//                DeferredTask {
//                    continuation.yield(1)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(2)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//
//                    XCTAssertEqual(elements2, [1, 2])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(3)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//
//                    XCTAssertEqual(elements2, [1, 2, 3])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(4)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//
//                    XCTAssertEqual(elements2, [1, 2, 3, 4])
//                }
//                .delayThenHandleOutput(for: .milliseconds(100), testClock: testClock) { _ in
//
//                    continuation.yield(5)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3, 4])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(6)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3, 4, 5])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5, 6])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(7)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3, 4, 5, 6])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5, 6, 7])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(8)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3, 4, 5, 6, 7])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5, 6, 7, 8])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(9)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    #warning("Flaked, got event 9")
//                    XCTAssertEqual(elements, [1, 2, 3, 4, 5, 6, 7, 8])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5, 6, 7, 8, 9])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(10)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3, 4, 5, 6, 7, 8, 9])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
//
//                    continuation.finish()
//
//                    let elements3 = await elementContainer.elements
//                    XCTAssertEqual(elements3, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
//                }
//                .run()
//            }.throttle(for: .milliseconds(10), clock: testClock, latest: true)
//
//            let task = Task {
//                for try await element in stream {
//                    await elementContainer.append(element)
//                }
//            }
//
//            _ = await task.result
//
//            let elements = await elementContainer.elements
//            XCTAssertEqual(elements, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
//        }
//    }
//
//    func testThrottleOnlyReturnsLatestElement_afterMultipleThrottleIntervalsHavePassed_10ms_andLatestIsFalse() async throws {
//        await withMainSerialExecutor {
//            let testClock = TestClock()
//            let elementContainer = ElementContainer()
//
//            let stream = AsyncStream { continuation in
//
//                DeferredTask {
//                    continuation.yield(1)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(2)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//
//                    XCTAssertEqual(elements2, [1, 2])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(3)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//
//                    XCTAssertEqual(elements2, [1, 2, 3])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(4)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//
//                    XCTAssertEqual(elements2, [1, 2, 3, 4])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(5)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3, 4])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(6)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3, 4, 5])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5, 6])
//                }
//                .delayThenHandleOutput(for: .milliseconds(100), testClock: testClock) { _ in
//
//                    continuation.yield(7)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3, 4, 5, 6])
//
//                    await testClock.advance(by: .milliseconds(95))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5, 6, 7])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(8)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3, 4, 5, 6, 7])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5, 6, 7, 8])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(9)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3, 4, 5, 6, 7, 8])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5, 6, 7, 8, 9])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(10)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3, 4, 5, 6, 7, 8, 9])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
//
//                    continuation.finish()
//
//                    let elements3 = await elementContainer.elements
//                    XCTAssertEqual(elements3, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
//                }
//                .run()
//            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
//
//            let task = Task {
//                for try await element in stream {
//                    await elementContainer.append(element)
//                }
//            }
//
//            _ = await task.result
//
//            let elements = await elementContainer.elements
//            XCTAssertEqual(elements, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
//        }
//    }
//
//    func testThrottleOnlyReturnsLatestElement_afterMultipleThrottleIntervalsHavePassedAtBeginning_10ms_andLatestIsTrue() async throws {
//        await withMainSerialExecutor {
//            let testClock = TestClock()
//            let elementContainer = ElementContainer()
//
//            let stream = AsyncStream { continuation in
//
//                DeferredTask {
//                    continuation.yield(1)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1])
//                }
//                .delayThenHandleOutput(for: .milliseconds(100), testClock: testClock) { _ in
//
//                    continuation.yield(2)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//
//                    XCTAssertEqual(elements2, [1, 2])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(3)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//
//                    XCTAssertEqual(elements2, [1, 2, 3])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(4)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//
//                    XCTAssertEqual(elements2, [1, 2, 3, 4])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(5)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3, 4])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(6)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3, 4, 5])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5, 6])
//                }
//                .delayThenHandleOutput(for: .milliseconds(100), testClock: testClock) { _ in
//
//                    continuation.yield(7)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3, 4, 5, 6])
//
//                    await testClock.advance(by: .milliseconds(95))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5, 6, 7])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(8)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3, 4, 5, 6, 7])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5, 6, 7, 8])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(9)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3, 4, 5, 6, 7, 8])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5, 6, 7, 8, 9])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(10)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3, 4, 5, 6, 7, 8, 9])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
//
//                    continuation.finish()
//
//                    let elements3 = await elementContainer.elements
//                    XCTAssertEqual(elements3, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
//                }
//                .run()
//            }.throttle(for: .milliseconds(10), clock: testClock, latest: true)
//
//            let task = Task {
//                for try await element in stream {
//                    await elementContainer.append(element)
//                }
//            }
//
//            _ = await task.result
//
//            let elements = await elementContainer.elements
//            XCTAssertEqual(elements, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
//        }
//    }
//
//    func testThrottleOnlyReturnsLatestElement_afterMultipleThrottleIntervalsHavePassedAtBeginning_10ms_andLatestIsFalse() async throws {
//        await withMainSerialExecutor {
//            let testClock = TestClock()
//            let elementContainer = ElementContainer()
//
//            let stream = AsyncStream { continuation in
//
//                DeferredTask {
//                    continuation.yield(1)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1])
//                }
//                .delayThenHandleOutput(for: .milliseconds(100), testClock: testClock) { _ in
//
//                    continuation.yield(2)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//
//                    XCTAssertEqual(elements2, [1, 2])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(3)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//
//                    XCTAssertEqual(elements2, [1, 2, 3])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(4)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//
//                    XCTAssertEqual(elements2, [1, 2, 3, 4])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(5)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3, 4])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(6)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3, 4, 5])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5, 6])
//                }
//                .delayThenHandleOutput(for: .milliseconds(100), testClock: testClock) { _ in
//
//                    continuation.yield(7)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3, 4, 5, 6])
//
//                    await testClock.advance(by: .milliseconds(95))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5, 6, 7])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(8)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3, 4, 5, 6, 7])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5, 6, 7, 8])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(9)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3, 4, 5, 6, 7, 8])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5, 6, 7, 8, 9])
//                }
//                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
//
//                    continuation.yield(10)
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 3, 4, 5, 6, 7, 8, 9])
//
//                    await testClock.advance(by: .milliseconds(5))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
//
//                    continuation.finish()
//
//                    let elements3 = await elementContainer.elements
//                    XCTAssertEqual(elements3, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
//                }
//                .run()
//            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
//
//            let task = Task {
//                for try await element in stream {
//                    await elementContainer.append(element)
//                }
//            }
//
//            _ = await task.result
//
//            let elements = await elementContainer.elements
//            XCTAssertEqual(elements, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
//        }
//    }
//
//    func testThrottleOnlyReturnsLatestElementInInterval_whenMultipleElementsAreReceivedDuringEachThrottleInterval_20ms_andLatestIsTrue() async throws {
//        await withMainSerialExecutor {
//            let testClock = TestClock()
//            let elementContainer = ElementContainer()
//            let stream = AsyncStream { continuation in
//                DeferredTask {
//                    continuation.yield(1)
//                    continuation.yield(2)
//                    continuation.yield(3)
//                    continuation.yield(4)
//                    continuation.yield(5)
//                    await testClock.advance(by: .milliseconds(10))
//
//                    let elements3 = await elementContainer.elements
//                    XCTAssertEqual(elements3, [1])
//
//                    await testClock.advance(by: .milliseconds(10))
//
//                    let elements4 = await elementContainer.elements
//                    XCTAssertEqual(elements4, [1, 5])
//                }
//                .delayThenHandleOutput(for: .milliseconds(20), testClock: testClock) { _ in
//                    continuation.yield(6)
//                    continuation.yield(7)
//                    continuation.yield(8)
//                    continuation.yield(9)
//                    continuation.yield(10)
//
//                    await testClock.advance(by: .milliseconds(10))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 5])
//
//                    await testClock.advance(by: .milliseconds(10))
//
//                    let elements4 = await elementContainer.elements
//                    XCTAssertEqual(elements4, [1, 5, 10])
//
//                    continuation.finish()
//
//                    let elements5 = await elementContainer.elements
//                    XCTAssertEqual(elements5, [1, 5, 10])
//                }.run()
//            }.throttle(for: .milliseconds(20), clock: testClock, latest: true)
//
//            let task = Task {
//                for try await element in stream {
//                    await elementContainer.append(element)
//                }
//            }
//
//            _ = await task.result
//
//            let elements = await elementContainer.elements
//            XCTAssertEqual(elements, [1, 5, 10])
//        }
//    }
//
//    func testThrottleOnlyReturnsLatestElementInInterval_whenMultipleElementsAreReceivedDuringEachThrottleInterval_20ms_andLatestIsFalse() async throws {
//        await withMainSerialExecutor {
//            let testClock = TestClock()
//            let elementContainer = ElementContainer()
//            let stream = AsyncStream { continuation in
//                DeferredTask {
//                    continuation.yield(1)
//                    continuation.yield(2)
//                    continuation.yield(3)
//                    continuation.yield(4)
//                    continuation.yield(5)
//                    await testClock.advance(by: .milliseconds(10))
//
//                    let elements3 = await elementContainer.elements
//                    XCTAssertEqual(elements3, [1])
//
//                    await testClock.advance(by: .milliseconds(10))
//
//                    let elements4 = await elementContainer.elements
//                    XCTAssertEqual(elements4, [1, 2])
//                }
//                .delayThenHandleOutput(for: .milliseconds(20), testClock: testClock) { _ in
//                    continuation.yield(6)
//                    continuation.yield(7)
//                    continuation.yield(8)
//                    continuation.yield(9)
//                    continuation.yield(10)
//
//                    await testClock.advance(by: .milliseconds(10))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2])
//
//                    await testClock.advance(by: .milliseconds(10))
//
//                    let elements4 = await elementContainer.elements
//                    XCTAssertEqual(elements4, [1, 2, 6])
//
//                    continuation.finish()
//
//                    let elements5 = await elementContainer.elements
//                    XCTAssertEqual(elements5, [1, 2, 6])
//                }
//                .run()
//            }.throttle(for: .milliseconds(20), clock: testClock, latest: false)
//
//            let task = Task {
//                for try await element in stream {
//                    await elementContainer.append(element)
//                }
//            }
//
//            _ = await task.result
//
//            let elements = await elementContainer.elements
//            XCTAssertEqual(elements, [1, 2, 6])
//        }
//    }
//
//    func testThrottleOnlyReturnsLatestElementInInterval_whenMultipleElementsAreReceivedDuringEachThrottleInterval_30ms_andLatestIsTrue() async throws {
//        await withMainSerialExecutor {
//            let testClock = TestClock()
//            let elementContainer = ElementContainer()
//            let stream = AsyncStream { continuation in
//                DeferredTask {
//                    continuation.yield(1)
//                    continuation.yield(2)
//                    continuation.yield(3)
//                    continuation.yield(4)
//                    continuation.yield(5)
//                    await testClock.advance(by: .milliseconds(10))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1])
//
//                    await testClock.advance(by: .milliseconds(10))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1])
//
//                    await testClock.advance(by: .milliseconds(10))
//
//                    let elements3 = await elementContainer.elements
//                    XCTAssertEqual(elements3, [1, 5])
//                }
//                .delayThenHandleOutput(for: .milliseconds(30), testClock: testClock) { _ in
//                    continuation.yield(6)
//                    continuation.yield(7)
//
//                    await testClock.advance(by: .milliseconds(10))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 5])
//
//                    await testClock.advance(by: .milliseconds(10))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 5])
//
//                    await testClock.advance(by: .milliseconds(10))
//
//                    let elements3 = await elementContainer.elements
//                    XCTAssertEqual(elements3, [1, 5, 7])
//                }
//                .delayThenHandleOutput(for: .milliseconds(30), testClock: testClock) { _ in
//                    continuation.yield(8)
//                    continuation.yield(9)
//                    continuation.yield(10)
//
//                    await testClock.advance(by: .milliseconds(10))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 5, 7])
//
//                    await testClock.advance(by: .milliseconds(10))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 5, 7])
//
//                    await testClock.advance(by: .milliseconds(10))
//
//                    let elements3 = await elementContainer.elements
//                    XCTAssertEqual(elements3, [1, 5, 7, 10])
//
//                    continuation.finish()
//
//                    let elements4 = await elementContainer.elements
//                    XCTAssertEqual(elements4, [1, 5, 7, 10])
//                }
//                .run()
//            }.throttle(for: .milliseconds(30), clock: testClock, latest: true)
//
//            let task = Task {
//                for try await element in stream {
//                    await elementContainer.append(element)
//                }
//            }
//
//            _ = await task.result
//
//            let elements = await elementContainer.elements
//            XCTAssertEqual(elements, [1, 5, 7, 10])
//        }
//    }
//
//    func testThrottleOnlyReturnsLatestElementInInterval_whenMultipleElementsAreReceivedDuringEachThrottleInterval_30ms_andLatestIsFalse() async throws {
//        await withMainSerialExecutor {
//            let testClock = TestClock()
//            let elementContainer = ElementContainer()
//            let stream = AsyncStream { continuation in
//                DeferredTask {
//                    continuation.yield(1)
//                    continuation.yield(2)
//                    continuation.yield(3)
//                    continuation.yield(4)
//                    continuation.yield(5)
//                    await testClock.advance(by: .milliseconds(10))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1])
//
//                    await testClock.advance(by: .milliseconds(10))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1])
//
//                    await testClock.advance(by: .milliseconds(10))
//
//                    let elements3 = await elementContainer.elements
//                    XCTAssertEqual(elements3, [1, 2])
//                }
//                .delayThenHandleOutput(for: .milliseconds(30), testClock: testClock) { _ in
//                    continuation.yield(6)
//                    continuation.yield(7)
//
//                    await testClock.advance(by: .milliseconds(10))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2])
//
//                    await testClock.advance(by: .milliseconds(10))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2])
//
//                    await testClock.advance(by: .milliseconds(10))
//
//                    let elements3 = await elementContainer.elements
//                    XCTAssertEqual(elements3, [1, 2, 6])
//                }
//                .delayThenHandleOutput(for: .milliseconds(30), testClock: testClock) { _ in
//                    continuation.yield(8)
//                    continuation.yield(9)
//                    continuation.yield(10)
//
//                    await testClock.advance(by: .milliseconds(10))
//
//                    let elements = await elementContainer.elements
//                    XCTAssertEqual(elements, [1, 2, 6])
//
//                    await testClock.advance(by: .milliseconds(10))
//
//                    let elements2 = await elementContainer.elements
//                    XCTAssertEqual(elements2, [1, 2, 6])
//
//                    await testClock.advance(by: .milliseconds(10))
//
//                    let elements3 = await elementContainer.elements
//                    XCTAssertEqual(elements3, [1, 2, 6, 8])
//
//                    continuation.finish()
//
//                    let elements4 = await elementContainer.elements
//                    XCTAssertEqual(elements4, [1, 2, 6, 8])
//                }
//                .run()
//            }.throttle(for: .milliseconds(30), clock: testClock, latest: false)
//
//            let task = Task {
//                for try await element in stream {
//                    await elementContainer.append(element)
//                }
//            }
//
//            _ = await task.result
//
//            let elements = await elementContainer.elements
//            XCTAssertEqual(elements, [1, 2, 6, 8])
//        }
//    }
}

@available(iOS 16.0, *)
extension AsynchronousUnitOfWork {
    fileprivate func delayThenHandleOutput<D: DurationProtocol & Hashable>(for duration: Duration, testClock: TestClock<D>, handler: @escaping (Sendable) async -> Void) -> some AsynchronousUnitOfWork {
        delay(for: duration)
            .handleEvents(receiveOutput: { output in
                Task {
                    guard let advance = duration as? D else { return }
                    await testClock.advance(by: advance)
                    await handler(output)
                }
            })
    }
}
