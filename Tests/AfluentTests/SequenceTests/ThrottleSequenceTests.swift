//
//  ThrottleSequenceTests.swift
//
//
//  Created by Trip Phillips on 2/12/24.
//

import Foundation
import XCTest
import Afluent
import Clocks
import ConcurrencyExtras
import Combine

@available(iOS 16.0, *)
final class ThrottleSequenceTests: XCTestCase {
    
    enum TestError: Error {
        case upstreamError
    }
    
    actor ElementContainer {
        var elements = [Int]()
        
        func append(_ element: Int) {
            elements.append(element)
        }
    }
    
    func testThrottleChecksForCancellation() async throws {
        try await withMainSerialExecutor {
            let testClock = TestClock()
            
            let stream = AsyncStream<Int> { continuation in
                continuation.finish()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: true)
            
            let task = Task {
                for try await _ in stream { }
            }
            
            task.cancel()
            
            let result = await task.result
            
            XCTAssertThrowsError(try result.get()) { error in
                XCTAssertNotNil(error as? CancellationError)
            }
        }
    }
    
    func testThrottleWithNoElements_returnsEmpty_andLatestIsTrue() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let elementContainer = ElementContainer()
            
            let stream = AsyncStream<Int> { continuation in
                continuation.finish()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: true)
            
            let task = Task {
                for try await element in stream {
                    await elementContainer.append(element)
                }
            }
            
            _ = await task.result
            
            let elements = await elementContainer.elements
            XCTAssert(elements.isEmpty)
        }
    }
    
    func testThrottleWithNoElements_returnsEmpty_andLatestIsFalse() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let elementContainer = ElementContainer()
            
            let stream = AsyncStream<Int> { continuation in
                continuation.finish()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
            
            let task = Task {
                for try await element in stream {
                    await elementContainer.append(element)
                }
            }
            
            _ = await task.result
            
            let elements = await elementContainer.elements
            XCTAssert(elements.isEmpty)
        }
    }
    
    func testThrottleWithOneElement_returnsOneElement_andLatestIsTrue() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let elementContainer = ElementContainer()
            
            let stream = AsyncStream<Int> { continuation in
                continuation.yield(1)
                continuation.finish()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: true)
            
            let task = Task {
                for try await element in stream {
                    await elementContainer.append(element)
                }
            }
            
            _ = await task.result
            
            let elements = await elementContainer.elements
            XCTAssertEqual(elements, [1])
        }
    }
    
    func testThrottleWithOneElement_returnsOneElement_andLatestIsFalse() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let elementContainer = ElementContainer()
            
            let stream = AsyncStream<Int> { continuation in
                continuation.yield(1)
                continuation.finish()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
            
            let task = Task {
                for try await element in stream {
                    await elementContainer.append(element)
                }
            }
            
            _ = await task.result
            
            let elements = await elementContainer.elements
            XCTAssertEqual(elements, [1])
        }
    }
    
    func testThrottleReturnsFirstAndLatestElementImmediately_whenReceivingMultipleElementsAtOnceAndStreamEnds_andLatestIsTrue() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let elementContainer = ElementContainer()
            
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
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,10])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    
                    XCTAssertEqual(elements2, [1,10])
                }.run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: true)
            
            let task = Task {
                for try await element in stream {
                    await elementContainer.append(element)
                }
            }
            
            _ = await task.result
            
            let elements = await elementContainer.elements
            XCTAssertEqual(elements, [1, 10])
        }
    }
    
    func testThrottleReturnsFirstAndSecondElementImmediately_whenReceivingMultipleElementsAtOnceAndStreamEnds_andLatestIsFalse() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let elementContainer = ElementContainer()
            
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
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    
                    XCTAssertEqual(elements2, [1,2])
                }.run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
            
            let task = Task {
                for try await element in stream {
                    await elementContainer.append(element)
                }
            }
            
            _ = await task.result
            
            let elements = await elementContainer.elements
            XCTAssertEqual(elements, [1, 2])
        }
    }
    
    func testThrottleReturnsLatestElementInIntervalBeforeErrorInStream_whenLatestIsTrue() async {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let elementContainer = ElementContainer()
            
            let stream = AsyncThrowingStream { continuation in
                continuation.yield(1)
                continuation.yield(2)
                continuation.yield(3)
                continuation.yield(with: .failure(TestError.upstreamError))
                continuation.yield(4)
                continuation.finish()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: true)
            
            let task = Task {
                do {
                    for try await element in stream {
                        await elementContainer.append(element)
                    }
                } catch {
                    XCTAssertNotNil(error as? TestError)
                }
            }
            
            _ = await task.result
            
            let elements = await elementContainer.elements
            XCTAssertEqual(elements, [1, 3])
        }
    }
    
    func testThrottleReturnsFirstElementInIntervalBeforeErrorInStream_whenLatestIsFalse() async {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let elementContainer = ElementContainer()
            
            let stream = AsyncThrowingStream { continuation in
                continuation.yield(1)
                continuation.yield(2)
                continuation.yield(3)
                continuation.yield(with: .failure(TestError.upstreamError))
                continuation.yield(4)
                continuation.finish()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
            
            let task = Task {
                do {
                    for try await element in stream {
                        await elementContainer.append(element)
                    }
                } catch {
                    XCTAssertNotNil(error as? TestError)
                }
            }
            
            _ = await task.result
            
            let elements = await elementContainer.elements
            XCTAssertEqual(elements, [1, 2])
        }
    }
    
    func testThrottleReturnsLatestElementInIntervalBeforeErrorInStreamWithDelay_whenLatestIsTrue() async {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let elementContainer = ElementContainer()
            
            let stream = AsyncThrowingStream { continuation in
                DeferredTask {
                    continuation.yield(1)
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1])
                    
                    continuation.yield(2)
                    continuation.yield(3)
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1, 3])
                    
                    continuation.yield(with: .failure(TestError.upstreamError))
                    continuation.yield(4)
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1, 3])
                    
                    continuation.finish()
                }
                .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: true)
            
            let task = Task {
                do {
                    for try await element in stream {
                        await elementContainer.append(element)
                    }
                } catch {
                    XCTAssertNotNil(error as? TestError)
                }
            }
            
            _ = await task.result
            
            let elements = await elementContainer.elements
            XCTAssertEqual(elements, [1, 3])
        }
    }
    
    func testThrottleReturnsFirstElementInIntervalBeforeErrorInStreamWithDelay_whenLatestIsFalse() async {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let elementContainer = ElementContainer()
            
            let stream = AsyncThrowingStream { continuation in
                DeferredTask {
                    continuation.yield(1)
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1])
                    
                    continuation.yield(2)
                    continuation.yield(3)
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1, 2])
                    
                    continuation.yield(with: .failure(TestError.upstreamError))
                    continuation.yield(4)
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1, 2])
                    
                    continuation.finish()
                }
                .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
            
            let task = Task {
                do {
                    for try await element in stream {
                        await elementContainer.append(element)
                    }
                } catch {
                    XCTAssertNotNil(error as? TestError)
                }
            }
            
            _ = await task.result
            
            let elements = await elementContainer.elements
            XCTAssertEqual(elements, [1, 2])
        }
    }
    
    func testThrottleReturnsLatestElementInIntervalThatCompletesThrowingError_whenLatestIsTrue() async {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let elementContainer = ElementContainer()
            
            let stream = AsyncThrowingStream { continuation in
                continuation.yield(1)
                continuation.yield(2)
                continuation.yield(3)
                continuation.finish(throwing: TestError.upstreamError)
            }.throttle(for: .milliseconds(10), clock: testClock, latest: true)
            
            let task = Task {
                do {
                    for try await element in stream {
                        await elementContainer.append(element)
                    }
                } catch {
                    XCTAssertNotNil(error as? TestError)
                }
            }
            
            _ = await task.result
            
            let elements = await elementContainer.elements
            XCTAssertEqual(elements, [1, 3])
        }
    }
    
    func testThrottleReturnsFirstElementInIntervalThatCompletesThrowingError_whenLatestIsFalse() async {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let elementContainer = ElementContainer()
            
            let stream = AsyncThrowingStream { continuation in
                continuation.yield(1)
                continuation.yield(2)
                continuation.yield(3)
                continuation.finish(throwing: TestError.upstreamError)
            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
            
            let task = Task {
                do {
                    for try await element in stream {
                        await elementContainer.append(element)
                    }
                } catch {
                    XCTAssertNotNil(error as? TestError)
                }
            }
            
            _ = await task.result
            
            let elements = await elementContainer.elements
            XCTAssertEqual(elements, [1, 2])
        }
    }
    
    func testThrottleOnlyThrottlesAfterFirstElementIsReceived_whenLatestIsTrue() async {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let elementContainer = ElementContainer()
            
            let stream = AsyncThrowingStream { continuation in
                DeferredTask {
                    continuation.yield(1)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(2)
                    continuation.yield(3)
                    continuation.yield(4)
                    continuation.yield(5)
                    continuation.yield(6)
                    continuation.yield(7)
                    continuation.yield(8)
                    continuation.yield(9)
                    continuation.yield(10)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,10])
                    
                    continuation.finish()
                    
                    let elements3 = await elementContainer.elements
                    XCTAssertEqual(elements3, [1,10])
                }
                .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: true)
            
            let task = Task {
                do {
                    for try await element in stream {
                        await elementContainer.append(element)
                    }
                } catch {
                    XCTAssertNotNil(error as? TestError)
                }
            }
            
            _ = await task.result
            
            let elements = await elementContainer.elements
            XCTAssertEqual(elements, [1, 10])
        }
    }
    
    func testThrottleOnlyThrottlesAfterFirstElementIsReceived_whenLatestIsFalse() async {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let elementContainer = ElementContainer()
            
            let stream = AsyncThrowingStream { continuation in
                DeferredTask {
                    continuation.yield(1)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(2)
                    continuation.yield(3)
                    continuation.yield(4)
                    continuation.yield(5)
                    continuation.yield(6)
                    continuation.yield(7)
                    continuation.yield(8)
                    continuation.yield(9)
                    continuation.yield(10)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2])
                    
                    continuation.finish()
                    
                    let elements3 = await elementContainer.elements
                    XCTAssertEqual(elements3, [1,2])
                }
                .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
            
            let task = Task {
                do {
                    for try await element in stream {
                        await elementContainer.append(element)
                    }
                } catch {
                    XCTAssertNotNil(error as? TestError)
                }
            }
            
            _ = await task.result
            
            let elements = await elementContainer.elements
            XCTAssertEqual(elements, [1, 2])
        }
    }
    
    func testThrottleReturnsAllElements_whenOnlyOneElementIsReceivedDuringEachThrottleInterval_10ms_andLatestIsTrue() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let elementContainer = ElementContainer()
            
            let stream = AsyncStream { continuation in
                
                DeferredTask {
                    continuation.yield(1)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(2)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    
                    XCTAssertEqual(elements2, [1,2])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(3)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    
                    XCTAssertEqual(elements2, [1,2,3])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(4)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    
                    XCTAssertEqual(elements2, [1,2,3,4])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(5)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(6)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(7)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5,6])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6,7])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(8)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5,6,7])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6,7,8])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(9)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5,6,7,8])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6,7,8,9])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(10)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5,6,7,8,9])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6,7,8,9,10])
                    
                    continuation.finish()
                    
                    let elements3 = await elementContainer.elements
                    XCTAssertEqual(elements3, [1,2,3,4,5,6,7,8,9,10])
                }
                .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: true)
            
            let task = Task {
                for try await element in stream {
                    await elementContainer.append(element)
                }
            }
            
            _ = await task.result
            
            let elements = await elementContainer.elements
            XCTAssertEqual(elements, [1,2,3,4,5,6,7,8,9,10])
        }
    }
    
    func testThrottleReturnsAllElements_whenOnlyOneElementIsReceivedDuringEachThrottleInterval_10ms_andLatestIsFalse() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let elementContainer = ElementContainer()
            
            let stream = AsyncStream { continuation in
                
                DeferredTask {
                    continuation.yield(1)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(2)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    
                    XCTAssertEqual(elements2, [1,2])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(3)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    
                    XCTAssertEqual(elements2, [1,2,3])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(4)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    
                    XCTAssertEqual(elements2, [1,2,3,4])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(5)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(6)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(7)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5,6])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6,7])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(8)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5,6,7])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6,7,8])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(9)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5,6,7,8])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6,7,8,9])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(10)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5,6,7,8,9])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6,7,8,9,10])
                    
                    continuation.finish()
                    
                    let elements3 = await elementContainer.elements
                    XCTAssertEqual(elements3, [1,2,3,4,5,6,7,8,9,10])
                }
                .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
            
            let task = Task {
                for try await element in stream {
                    await elementContainer.append(element)
                }
            }
            
            _ = await task.result
            
            let elements = await elementContainer.elements
            XCTAssertEqual(elements, [1,2,3,4,5,6,7,8,9,10])
        }
    }
    
    func testThrottleOnlyReturnsLatestElementInInterval_whenMultipleElementsAreReceivedDuringEachThrottleInterval_10ms_andLatestIsTrue() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let elementContainer = ElementContainer()
            
            let stream = AsyncStream { continuation in
                DeferredTask {
                    continuation.yield(1)
                    continuation.yield(2)
                    continuation.yield(3)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,3])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    continuation.yield(4)
                    continuation.yield(5)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,3])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,3,5])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    continuation.yield(6)
                    continuation.yield(7)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,3,5])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,3,5,7])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    continuation.yield(8)
                    continuation.yield(9)
                    continuation.yield(10)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,3,5,7])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,3,5,7,10])
                    
                    continuation.finish()
                    
                    let elements3 = await elementContainer.elements
                    XCTAssertEqual(elements3, [1,3,5,7,10])
                }
                .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: true)
            
            let task = Task {
                for try await element in stream {
                    await elementContainer.append(element)
                }
            }
            
            _ = await task.result
            
            let elements = await elementContainer.elements
            XCTAssertEqual(elements, [1,3,5,7,10])
        }
    }
    
    func testThrottleOnlyReturnsFirstElementInInterval_whenMultipleElementsAreReceivedDuringEachThrottleInterval_10ms_andLatestIsFalse() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let elementContainer = ElementContainer()
            
            let stream = AsyncStream { continuation in
                DeferredTask {
                    continuation.yield(1)
                    continuation.yield(2)
                    continuation.yield(3)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    continuation.yield(4)
                    continuation.yield(5)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,4])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    continuation.yield(6)
                    continuation.yield(7)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,4])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,4,6])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    continuation.yield(8)
                    continuation.yield(9)
                    continuation.yield(10)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,4,6])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,4,6,8])
                    
                    continuation.finish()
                    
                    let elements3 = await elementContainer.elements
                    XCTAssertEqual(elements3, [1,2,4,6,8])
                }
                .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
            
            let task = Task {
                for try await element in stream {
                    await elementContainer.append(element)
                }
            }
            
            _ = await task.result
            
            let elements = await elementContainer.elements
            XCTAssertEqual(elements, [1,2,4,6,8])
        }
    }
    
    func testThrottleOnlyReturnsLatestElement_whenMultipleElementsAreReceivedAfterMultipleThrottleIntervalsHavePassed_10ms_andLatestIsTrue() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let elementContainer = ElementContainer()
            
            let stream = AsyncStream { continuation in
                DeferredTask {
                    continuation.yield(1)
                }
                .delayThenHandleOutput(for: .milliseconds(100), testClock: testClock) { _ in
                    continuation.yield(2)
                    continuation.yield(3)
                    continuation.yield(4)
                    continuation.yield(6)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1])
                    
                    continuation.yield(7)
                    continuation.yield(8)
                    continuation.yield(9)
                    continuation.yield(10)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1, 10])
                    
                    continuation.finish()
                    
                    let elements3 = await elementContainer.elements
                    XCTAssertEqual(elements3, [1, 10])
                }
                .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: true)
            
            let task = Task {
                for try await element in stream {
                    await elementContainer.append(element)
                }
            }
            
            _ = await task.result
            
            let elements = await elementContainer.elements
            XCTAssertEqual(elements, [1,10])
        }
    }
    
    func testThrottleOnlyReturnsLatestElement_whenMultipleElementsAreReceivedAfterMultipleThrottleIntervalsHavePassed_10ms_andLatestIsFalse() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let elementContainer = ElementContainer()
            
            let stream = AsyncStream { continuation in
                DeferredTask {
                    continuation.yield(1)
                }
                .delayThenHandleOutput(for: .milliseconds(100), testClock: testClock) { _ in
                    continuation.yield(2)
                    continuation.yield(3)
                    continuation.yield(4)
                    continuation.yield(6)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1])
                    
                    continuation.yield(7)
                    continuation.yield(8)
                    continuation.yield(9)
                    continuation.yield(10)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1, 2])
                    
                    continuation.finish()
                    
                    let elements3 = await elementContainer.elements
                    XCTAssertEqual(elements3, [1, 2])
                }
                .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
            
            let task = Task {
                for try await element in stream {
                    await elementContainer.append(element)
                }
            }
            
            _ = await task.result
            
            let elements = await elementContainer.elements
            XCTAssertEqual(elements, [1,2])
        }
    }
    
    func testThrottleOnlyReturnsLatestElement_afterMultipleThrottleIntervalsHavePassed_10ms_andLatestIsTrue() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let elementContainer = ElementContainer()
            
            let stream = AsyncStream { continuation in
                
                DeferredTask {
                    continuation.yield(1)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(2)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    
                    XCTAssertEqual(elements2, [1,2])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(3)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    
                    XCTAssertEqual(elements2, [1,2,3])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(4)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    
                    XCTAssertEqual(elements2, [1,2,3,4])
                }
                .delayThenHandleOutput(for: .milliseconds(100), testClock: testClock) { _ in
                    
                    continuation.yield(5)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(6)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(7)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5,6])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6,7])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(8)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5,6,7])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6,7,8])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(9)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5,6,7,8])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6,7,8,9])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(10)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5,6,7,8,9])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6,7,8,9,10])
                    
                    continuation.finish()
                    
                    let elements3 = await elementContainer.elements
                    XCTAssertEqual(elements3, [1,2,3,4,5,6,7,8,9,10])
                }
                .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: true)
            
            let task = Task {
                for try await element in stream {
                    await elementContainer.append(element)
                }
            }
            
            _ = await task.result
            
            let elements = await elementContainer.elements
            XCTAssertEqual(elements, [1,2,3,4,5,6,7,8,9,10])
        }
    }
    
    func testThrottleOnlyReturnsLatestElement_afterMultipleThrottleIntervalsHavePassed_10ms_andLatestIsFalse() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let elementContainer = ElementContainer()
            
            let stream = AsyncStream { continuation in
                
                DeferredTask {
                    continuation.yield(1)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(2)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    
                    XCTAssertEqual(elements2, [1,2])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(3)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    
                    XCTAssertEqual(elements2, [1,2,3])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(4)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    
                    XCTAssertEqual(elements2, [1,2,3,4])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(5)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(6)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6])
                }
                .delayThenHandleOutput(for: .milliseconds(100), testClock: testClock) { _ in
                    
                    continuation.yield(7)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5,6])
                    
                    await testClock.advance(by: .milliseconds(95))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6,7])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(8)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5,6,7])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6,7,8])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(9)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5,6,7,8])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6,7,8,9])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(10)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5,6,7,8,9])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6,7,8,9,10])
                    
                    continuation.finish()
                    
                    let elements3 = await elementContainer.elements
                    XCTAssertEqual(elements3, [1,2,3,4,5,6,7,8,9,10])
                }
                .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
            
            let task = Task {
                for try await element in stream {
                    await elementContainer.append(element)
                }
            }
            
            _ = await task.result
            
            let elements = await elementContainer.elements
            XCTAssertEqual(elements, [1,2,3,4,5,6,7,8,9,10])
        }
    }
    
    func testThrottleOnlyReturnsLatestElement_afterMultipleThrottleIntervalsHavePassedAtBeginning_10ms_andLatestIsTrue() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let elementContainer = ElementContainer()
            
            let stream = AsyncStream { continuation in
                
                DeferredTask {
                    continuation.yield(1)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1])
                }
                .delayThenHandleOutput(for: .milliseconds(100), testClock: testClock) { _ in
                    
                    continuation.yield(2)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    
                    XCTAssertEqual(elements2, [1,2])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(3)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    
                    XCTAssertEqual(elements2, [1,2,3])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(4)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    
                    XCTAssertEqual(elements2, [1,2,3,4])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(5)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(6)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6])
                }
                .delayThenHandleOutput(for: .milliseconds(100), testClock: testClock) { _ in
                    
                    continuation.yield(7)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5,6])
                    
                    await testClock.advance(by: .milliseconds(95))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6,7])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(8)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5,6,7])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6,7,8])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(9)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5,6,7,8])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6,7,8,9])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(10)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5,6,7,8,9])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6,7,8,9,10])
                    
                    continuation.finish()
                    
                    let elements3 = await elementContainer.elements
                    XCTAssertEqual(elements3, [1,2,3,4,5,6,7,8,9,10])
                }
                .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: true)
            
            let task = Task {
                for try await element in stream {
                    await elementContainer.append(element)
                }
            }
            
            _ = await task.result
            
            let elements = await elementContainer.elements
            XCTAssertEqual(elements, [1,2,3,4,5,6,7,8,9,10])
        }
    }
    
    func testThrottleOnlyReturnsLatestElement_afterMultipleThrottleIntervalsHavePassedAtBeginning_10ms_andLatestIsFalse() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let elementContainer = ElementContainer()
            
            let stream = AsyncStream { continuation in
                
                DeferredTask {
                    continuation.yield(1)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1])
                }
                .delayThenHandleOutput(for: .milliseconds(100), testClock: testClock) { _ in
                    
                    continuation.yield(2)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    
                    XCTAssertEqual(elements2, [1,2])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(3)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    
                    XCTAssertEqual(elements2, [1,2,3])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(4)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    
                    XCTAssertEqual(elements2, [1,2,3,4])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(5)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(6)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6])
                }
                .delayThenHandleOutput(for: .milliseconds(100), testClock: testClock) { _ in
                    
                    continuation.yield(7)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5,6])
                    
                    await testClock.advance(by: .milliseconds(95))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6,7])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(8)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5,6,7])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6,7,8])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(9)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5,6,7,8])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6,7,8,9])
                }
                .delayThenHandleOutput(for: .milliseconds(10), testClock: testClock) { _ in
                    
                    continuation.yield(10)
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,3,4,5,6,7,8,9])
                    
                    await testClock.advance(by: .milliseconds(5))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,3,4,5,6,7,8,9,10])
                    
                    continuation.finish()
                    
                    let elements3 = await elementContainer.elements
                    XCTAssertEqual(elements3, [1,2,3,4,5,6,7,8,9,10])
                }
                .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
            
            let task = Task {
                for try await element in stream {
                    await elementContainer.append(element)
                }
            }
            
            _ = await task.result
            
            let elements = await elementContainer.elements
            XCTAssertEqual(elements, [1,2,3,4,5,6,7,8,9,10])
        }
    }
    
    func testThrottleOnlyReturnsLatestElementInInterval_whenMultipleElementsAreReceivedDuringEachThrottleInterval_20ms_andLatestIsTrue() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let elementContainer = ElementContainer()
            let stream = AsyncStream { continuation in
                DeferredTask {
                    continuation.yield(1)
                    continuation.yield(2)
                    continuation.yield(3)
                    continuation.yield(4)
                    continuation.yield(5)
                    await testClock.advance(by: .milliseconds(10))
                    
                    let elements3 = await elementContainer.elements
                    XCTAssertEqual(elements3, [1])
                    
                    await testClock.advance(by: .milliseconds(10))
                    
                    let elements4 = await elementContainer.elements
                    XCTAssertEqual(elements4, [1,5])
                }
                .delayThenHandleOutput(for: .milliseconds(20), testClock: testClock) { _ in
                    continuation.yield(6)
                    continuation.yield(7)
                    continuation.yield(8)
                    continuation.yield(9)
                    continuation.yield(10)
                    
                    await testClock.advance(by: .milliseconds(10))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,5])
                    
                    await testClock.advance(by: .milliseconds(10))
                    
                    let elements4 = await elementContainer.elements
                    XCTAssertEqual(elements4, [1,5,10])
                    
                    continuation.finish()
                    
                    let elements5 = await elementContainer.elements
                    XCTAssertEqual(elements5, [1,5,10])
                }.run()
            }.throttle(for: .milliseconds(20), clock: testClock, latest: true)
            
            let task = Task {
                for try await element in stream {
                    await elementContainer.append(element)
                }
            }
            
            _ = await task.result
            
            let elements = await elementContainer.elements
            XCTAssertEqual(elements, [1,5,10])
        }
    }
    
    func testThrottleOnlyReturnsLatestElementInInterval_whenMultipleElementsAreReceivedDuringEachThrottleInterval_20ms_andLatestIsFalse() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let elementContainer = ElementContainer()
            let stream = AsyncStream { continuation in
                DeferredTask {
                    continuation.yield(1)
                    continuation.yield(2)
                    continuation.yield(3)
                    continuation.yield(4)
                    continuation.yield(5)
                    await testClock.advance(by: .milliseconds(10))
                    
                    let elements3 = await elementContainer.elements
                    XCTAssertEqual(elements3, [1])
                    
                    await testClock.advance(by: .milliseconds(10))
                    
                    let elements4 = await elementContainer.elements
                    XCTAssertEqual(elements4, [1,2])
                }
                .delayThenHandleOutput(for: .milliseconds(20), testClock: testClock) { _ in
                    continuation.yield(6)
                    continuation.yield(7)
                    continuation.yield(8)
                    continuation.yield(9)
                    continuation.yield(10)
                    
                    await testClock.advance(by: .milliseconds(10))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2])
                    
                    await testClock.advance(by: .milliseconds(10))
                    
                    let elements4 = await elementContainer.elements
                    XCTAssertEqual(elements4, [1,2,6])
                    
                    continuation.finish()
                    
                    let elements5 = await elementContainer.elements
                    XCTAssertEqual(elements5, [1,2,6])
                }
                .run()
            }.throttle(for: .milliseconds(20), clock: testClock, latest: false)
            
            let task = Task {
                for try await element in stream {
                    await elementContainer.append(element)
                }
            }
            
            _ = await task.result
            
            let elements = await elementContainer.elements
            XCTAssertEqual(elements, [1,2,6])
        }
    }
    
    func testThrottleOnlyReturnsLatestElementInInterval_whenMultipleElementsAreReceivedDuringEachThrottleInterval_30ms_andLatestIsTrue() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let elementContainer = ElementContainer()
            let stream = AsyncStream { continuation in
                DeferredTask {
                    continuation.yield(1)
                    continuation.yield(2)
                    continuation.yield(3)
                    continuation.yield(4)
                    continuation.yield(5)
                    await testClock.advance(by: .milliseconds(10))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1])
                    
                    await testClock.advance(by: .milliseconds(10))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1])
                    
                    await testClock.advance(by: .milliseconds(10))
                    
                    let elements3 = await elementContainer.elements
                    XCTAssertEqual(elements3, [1,5])
                }
                .delayThenHandleOutput(for: .milliseconds(30), testClock: testClock) { _ in
                    continuation.yield(6)
                    continuation.yield(7)
                    
                    await testClock.advance(by: .milliseconds(10))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,5])
                    
                    await testClock.advance(by: .milliseconds(10))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,5])
                    
                    await testClock.advance(by: .milliseconds(10))
                    
                    let elements3 = await elementContainer.elements
                    XCTAssertEqual(elements3, [1,5,7])
                }
                .delayThenHandleOutput(for: .milliseconds(30), testClock: testClock) { _ in
                    continuation.yield(8)
                    continuation.yield(9)
                    continuation.yield(10)
                    
                    await testClock.advance(by: .milliseconds(10))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,5,7])
                    
                    await testClock.advance(by: .milliseconds(10))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,5,7])
                    
                    await testClock.advance(by: .milliseconds(10))
                    
                    let elements3 = await elementContainer.elements
                    XCTAssertEqual(elements3, [1,5,7,10])
                    
                    continuation.finish()
                    
                    let elements4 = await elementContainer.elements
                    XCTAssertEqual(elements4, [1,5,7,10])
                }
                .run()
            }.throttle(for: .milliseconds(30), clock: testClock, latest: true)
            
            let task = Task {
                for try await element in stream {
                    await elementContainer.append(element)
                }
            }
            
            _ = await task.result
            
            let elements = await elementContainer.elements
            XCTAssertEqual(elements, [1,5,7,10])
        }
    }
    
    func testThrottleOnlyReturnsLatestElementInInterval_whenMultipleElementsAreReceivedDuringEachThrottleInterval_30ms_andLatestIsFalse() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let elementContainer = ElementContainer()
            let stream = AsyncStream { continuation in
                DeferredTask {
                    continuation.yield(1)
                    continuation.yield(2)
                    continuation.yield(3)
                    continuation.yield(4)
                    continuation.yield(5)
                    await testClock.advance(by: .milliseconds(10))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1])
                    
                    await testClock.advance(by: .milliseconds(10))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1])
                    
                    await testClock.advance(by: .milliseconds(10))
                    
                    let elements3 = await elementContainer.elements
                    XCTAssertEqual(elements3, [1,2])
                }
                .delayThenHandleOutput(for: .milliseconds(30), testClock: testClock) { _ in
                    continuation.yield(6)
                    continuation.yield(7)
                    
                    await testClock.advance(by: .milliseconds(10))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2])
                    
                    await testClock.advance(by: .milliseconds(10))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2])
                    
                    await testClock.advance(by: .milliseconds(10))
                    
                    let elements3 = await elementContainer.elements
                    XCTAssertEqual(elements3, [1,2,6])
                }
                .delayThenHandleOutput(for: .milliseconds(30), testClock: testClock) { _ in
                    continuation.yield(8)
                    continuation.yield(9)
                    continuation.yield(10)
                    
                    await testClock.advance(by: .milliseconds(10))
                    
                    let elements = await elementContainer.elements
                    XCTAssertEqual(elements, [1,2,6])
                    
                    await testClock.advance(by: .milliseconds(10))
                    
                    let elements2 = await elementContainer.elements
                    XCTAssertEqual(elements2, [1,2,6])
                    
                    await testClock.advance(by: .milliseconds(10))
                    
                    let elements3 = await elementContainer.elements
                    XCTAssertEqual(elements3, [1,2,6,8])
                    
                    continuation.finish()
                    
                    let elements4 = await elementContainer.elements
                    XCTAssertEqual(elements4, [1,2,6,8])
                }
                .run()
            }.throttle(for: .milliseconds(30), clock: testClock, latest: false)
            
            let task = Task {
                for try await element in stream {
                    await elementContainer.append(element)
                }
            }
            
            _ = await task.result
            
            let elements = await elementContainer.elements
            XCTAssertEqual(elements, [1,2,6,8])
        }
    }
}

@available(iOS 16.0, *)
private extension AsynchronousUnitOfWork {
    func delayThenHandleOutput<D: DurationProtocol & Hashable>(for duration: Duration, testClock: TestClock<D>, handler: @escaping (Sendable) async -> Void) -> any AsynchronousUnitOfWork {
        self.delay(for: duration)
            .handleEvents(receiveOutput: { output in
                Task {
                    guard let advance = duration as? D else { return }
                    await testClock.advance(by: advance)
                    await handler(output)
                }
            })
    }
}
