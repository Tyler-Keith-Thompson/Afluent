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
    
    func testThrottleWithNoElements() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let stream = AsyncStream<Int> { continuation in
                continuation.finish()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: true)
            
            let task = Task {
                var elements = [Int]()
                
                for try await element in stream {
                    elements.append(element)
                }
                
                XCTAssert(elements.isEmpty)
            }
            
            _ = await task.result
        }
    }
    
    func testThrottleWithOneElement() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let stream = AsyncStream<Int> { continuation in
                continuation.yield(1)
                continuation.finish()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: true)
            
            let task = Task {
                var elements = [Int]()
                
                for try await element in stream {
                    elements.append(element)
                }
                
                XCTAssertEqual(elements, [1])
            }
        
            _ = await task.result
        }
    }
    
    func testThrottleOnlyReturnsFirstAndLatestElement_whenReceivingMultipleElementsAtOnce_andLatestIsTrue() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let stream = AsyncStream { continuation in
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
            }.throttle(for: .milliseconds(10), clock: testClock, latest: true)
            
            let task = Task {
                var elements = [Int]()
                
                for try await element in stream {
                    elements.append(element)
                }
                
                XCTAssertEqual(elements, [1, 10])
            }
            
            _ = await task.result
        }
    }
    
    func testThrottleOnlyReturnsFirstAndSecondElement_whenReceivingMultipleElementsAtOnce_andLatestIsFalse() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let stream = AsyncStream { continuation in
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
            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
            
            let task = Task {
                var elements = [Int]()
                
                for try await element in stream {
                    elements.append(element)
                }
                
                XCTAssertEqual(elements, [1, 2])
            }
        
            _ = await task.result
        }
    }
    
    func testThrottleReturnsLatestElementInIntervalBeforeError_whenLatestIsTrue() async {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let stream = AsyncThrowingStream { continuation in
                continuation.yield(1)
                continuation.yield(2)
                continuation.yield(3)
                continuation.yield(with: .failure(TestError.upstreamError))
                continuation.yield(4)
                continuation.finish()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: true)
            
            let task = Task {
                var elements = [Int]()
                do {
                    for try await element in stream {
                        elements.append(element)
                    }
                } catch {
                    XCTAssertNotNil(error as? TestError)
                }
                
                XCTAssertEqual(elements, [1, 3])
            }
            
            _ = await task.result
        }
    }
    
    func testThrottleReturnsFirstElementInIntervalBeforeError_whenLatestIsFalse() async {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let stream = AsyncThrowingStream { continuation in
                continuation.yield(1)
                continuation.yield(2)
                continuation.yield(3)
                continuation.yield(with: .failure(TestError.upstreamError))
                continuation.yield(4)
                continuation.finish()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
            
            let task = Task {
                var elements = [Int]()
                do {
                    for try await element in stream {
                        elements.append(element)
                    }
                } catch {
                    XCTAssertNotNil(error as? TestError)
                }
                
                XCTAssertEqual(elements, [1, 2])
            }
            
            _ = await task.result
        }
    }
    
    func testThrottleDoesNotThrottleUntilFirstValueIsReceived() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let stream = AsyncStream { continuation in
                DeferredTask { () }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(100)) {
                        continuation.yield(1)
                        continuation.yield(2)
                        continuation.yield(3)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(4)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(5)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(6)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(7)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(8)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(9)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(10)
                        continuation.finish()
                    }
                    .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: true)
            
            let task = Task {
                var elements = [Int]()
                
                for try await element in stream {
                    elements.append(element)
                }
                
                XCTAssertEqual(elements, [1,3,4,5,6,7,8,9,10])
            }
            
            _ = await task.result
        }
    }
    
    func testThrottleReturnsAllElements_whenOnlyOneElementIsReceivedDuringEachThrottleInterval_10ms_andLatestIsTrue() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let stream = AsyncStream { continuation in
                DeferredTask { () }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(1)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(2)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(3)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(4)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(5)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(6)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(7)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(8)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(9)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(10)
                        continuation.finish()
                    }
                    .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: true)
            
            let task = Task {
                var elements = [Int]()
                
                for try await element in stream {
                    elements.append(element)
                }
                
                XCTAssertEqual(elements, [1,2,3,4,5,6,7,8,9,10])
            }
            
            _ = await task.result
        }
    }
    
    func testThrottleReturnsAllElements_whenOnlyOneElementIsReceivedDuringEachThrottleInterval_10ms_andLatestIsFalse() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let stream = AsyncStream { continuation in
                DeferredTask { () }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(1)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(2)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(3)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(4)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(5)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(6)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(7)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(8)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(9)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(10)
                        continuation.finish()
                    }
                    .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
            
            let task = Task {
                var elements = [Int]()
                
                for try await element in stream {
                    elements.append(element)
                }
                
                XCTAssertEqual(elements, [1,2,3,4,5,6,7,8,9,10])
            }
            
            _ = await task.result
        }
    }
    
    func testThrottleOnlyReturnsLatestElementInInterval_whenMultipleElementsAreReceivedDuringEachThrottleInterval_10ms_andLatestIsTrue() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let stream = AsyncStream { continuation in
                DeferredTask { () }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(1)
                        continuation.yield(2)
                        continuation.yield(3)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(4)
                        continuation.yield(5)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(6)
                        continuation.yield(7)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(8)
                        continuation.yield(9)
                        continuation.yield(10)
                        continuation.finish()
                    }
                    .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: true)
            
            let task = Task {
                var elements = [Int]()
                
                for try await element in stream {
                    elements.append(element)
                }
                
                XCTAssertEqual(elements, [1,3,5,7,10])
            }
            
            _ = await task.result
        }
    }

    func testThrottleOnlyReturnsFirstElementInInterval_whenMultipleElementsAreReceivedDuringEachThrottleInterval_10ms_andLatestIsFalse() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let stream = AsyncStream { continuation in
                DeferredTask { () }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(1)
                        continuation.yield(2)
                        continuation.yield(3)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(4)
                        continuation.yield(5)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(6)
                        continuation.yield(7)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(8)
                        continuation.yield(9)
                        continuation.yield(10)
                        continuation.finish()
                    }
                    .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
            
            let task = Task {
                var elements = [Int]()
                
                for try await element in stream {
                    elements.append(element)
                }
                
                XCTAssertEqual(elements, [1,2,4,6,8])
            }
            
            _ = await task.result
        }
    }
    
    func testThrottleOnlyReturnsLatestElement_whenMultipleElementsAreReceivedAfterMultipleThrottleIntervalsHavePassed_10ms_andLatestIsTrue() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let stream = AsyncStream { continuation in
                DeferredTask { () }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(1)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(50)) {
                        continuation.yield(2)
                        continuation.yield(3)
                        continuation.yield(4)
                        continuation.yield(6)
                        continuation.yield(7)
                        continuation.yield(8)
                        continuation.yield(9)
                        continuation.yield(10)
                        continuation.finish()
                    }
                    .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: true)
            
            let task = Task {
                var elements = [Int]()
                
                for try await element in stream {
                    elements.append(element)
                }
                
                XCTAssertEqual(elements, [1,10])
            }
            
            _ = await task.result
        }
    }
    
    func testThrottleOnlyReturnsFirstElement_whenMultipleElementsAreReceivedAfterMultipleThrottleIntervalsHavePassed_10ms_andLatestIsFalse() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let stream = AsyncStream { continuation in
                DeferredTask { () }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(1)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(50)) {
                        continuation.yield(2)
                        continuation.yield(3)
                        continuation.yield(4)
                        continuation.yield(6)
                        continuation.yield(7)
                        continuation.yield(8)
                        continuation.yield(9)
                        continuation.yield(10)
                        continuation.finish()
                    }
                    .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
            
            let task = Task {
                var elements = [Int]()
                
                for try await element in stream {
                    elements.append(element)
                }
                
                XCTAssertEqual(elements, [1,2])
            }
            
            _ = await task.result
        }
    }
    
    func testThrottleOnlyReturnsLatestElement_afterMultipleThrottleIntervalsHavePassed_10ms_andLatestIsTrue() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let stream = AsyncStream { continuation in
                DeferredTask { () }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(1)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(2)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(3)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(4)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(100)) {
                        continuation.yield(5)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(6)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(7)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(8)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(9)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(10)
                        continuation.finish()
                    }
                    .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: true)
            
            let task = Task {
                var elements = [Int]()
                
                for try await element in stream {
                    elements.append(element)
                }
                
                XCTAssertEqual(elements, [1,2,3,4,5,6,7,8,9,10])
            }
            
            _ = await task.result
        }
    }
    
    func testThrottleOnlyReturnsLatestElement_afterMultipleThrottleIntervalsHavePassed_10ms_andLatestIsFalse() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let stream = AsyncStream { continuation in
                DeferredTask { () }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(1)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(2)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(3)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(4)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(100)) {
                        continuation.yield(5)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(6)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(7)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(8)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(9)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(10)
                        continuation.finish()
                    }
                    .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
            
            let task = Task {
                var elements = [Int]()
                
                for try await element in stream {
                    elements.append(element)
                }
                
                XCTAssertEqual(elements, [1,2,3,4,5,6,7,8,9,10])
            }
            
            _ = await task.result
        }
    }
    
    func testThrottleOnlyReturnsLatestElement_afterMultipleThrottleIntervalsHavePassedAtBeginning_10ms_andLatestIsTrue() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let stream = AsyncStream { continuation in
                DeferredTask { () }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(1)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(100)) {
                        continuation.yield(2)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(3)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(4)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(5)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(6)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(7)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(8)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(9)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(10)
                        continuation.finish()
                    }
                    .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
            
            let task = Task {
                var elements = [Int]()
                
                for try await element in stream {
                    elements.append(element)
                }
                
                XCTAssertEqual(elements, [1,2,3,4,5,6,7,8,9,10])
            }
            
            _ = await task.result
        }
    }
    
    func testThrottleOnlyReturnsLatestElement_afterMultipleThrottleIntervalsHavePassedAtBeginning_10ms_andLatestIsFalse() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let stream = AsyncStream { continuation in
                DeferredTask { () }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(1)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(100)) {
                        continuation.yield(2)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(3)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(4)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(5)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(6)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(7)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(8)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(9)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(10)
                        continuation.finish()
                    }
                    .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
            
            let task = Task {
                var elements = [Int]()
                
                for try await element in stream {
                    elements.append(element)
                }
                
                XCTAssertEqual(elements, [1,2,3,4,5,6,7,8,9,10])
            }
            
            _ = await task.result
        }
    }
    
    func testThrottleOnlyReturnsLatestElementInInterval_whenMultipleElementsAreReceivedDuringEachThrottleInterval_20ms_andLatestIsTrue() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let stream = AsyncStream { continuation in
                DeferredTask { () }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(1)
                        continuation.yield(2)
                        continuation.yield(3)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(4)
                        continuation.yield(5)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(6)
                        continuation.yield(7)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(8)
                        continuation.yield(9)
                        continuation.yield(10)
                        continuation.finish()
                    }
                    .run()
            }.throttle(for: .milliseconds(20), clock: testClock, latest: true)
            
            let task = Task {
                var elements = [Int]()
                
                for try await element in stream {
                    elements.append(element)
                }
                
                XCTAssertEqual(elements, [1,5,10])
            }
            
            _ = await task.result
        }
    }

    func testThrottleOnlyReturnsLatestElementInInterval_whenMultipleElementsAreReceivedDuringEachThrottleInterval_20ms_andLatestIsFalse() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let stream = AsyncStream { continuation in
                DeferredTask { () }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(1)
                        continuation.yield(2)
                        continuation.yield(3)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(4)
                        continuation.yield(5)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(6)
                        continuation.yield(7)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(8)
                        continuation.yield(9)
                        continuation.yield(10)
                        continuation.finish()
                    }
                    .run()
            }.throttle(for: .milliseconds(20), clock: testClock, latest: false)
            
            let task = Task {
                var elements = [Int]()
                
                for try await element in stream {
                    elements.append(element)
                }
                
                XCTAssertEqual(elements, [1,2,6])
            }
            
            _ = await task.result
        }
    }
    
    func testThrottleOnlyReturnsLatestElementInInterval_whenMultipleElementsAreReceivedDuringEachThrottleInterval_30ms_andLatestIsTrue() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let stream = AsyncStream { continuation in
                DeferredTask { () }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(1)
                        continuation.yield(2)
                        continuation.yield(3)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(4)
                        continuation.yield(5)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(6)
                        continuation.yield(7)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(8)
                        continuation.yield(9)
                        continuation.yield(10)
                        continuation.finish()
                    }
                    .run()
            }.throttle(for: .milliseconds(30), clock: testClock, latest: true)
            
            let task = Task {
                var elements = [Int]()
                
                for try await element in stream {
                    elements.append(element)
                }
                
                XCTAssertEqual(elements, [1,7,10])
            }
            
            _ = await task.result
        }
    }

    func testThrottleOnlyReturnsFirstElementInInterval_whenMultipleElementsAreReceivedDuringEachThrottleInterval_30ms_andLatestIsFalse() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let stream = AsyncStream { continuation in
                DeferredTask { () }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(1)
                        continuation.yield(2)
                        continuation.yield(3)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(4)
                        continuation.yield(5)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(6)
                        continuation.yield(7)
                    }
                    .delayAndAdvance(clock: testClock, delay: .milliseconds(10)) {
                        continuation.yield(8)
                        continuation.yield(9)
                        continuation.yield(10)
                        continuation.finish()
                    }
                    .run()
            }.throttle(for: .milliseconds(30), clock: testClock, latest: false)
            
            let task = Task {
                var elements = [Int]()
                
                for try await element in stream {
                    elements.append(element)
                }
                
                XCTAssertEqual(elements, [1,2,8])
            }
            
            _ = await task.result
        }
    }
}

@available(iOS 16.0, *)
extension AsynchronousUnitOfWork {
    func delayAndAdvance<D: DurationProtocol & Hashable>(clock: TestClock<D>, delay: Duration, completion: @escaping () -> Void) -> any AsynchronousUnitOfWork {
        self.delay(for: delay)
            .handleEvents(receiveOutput: { _ in
                guard let advance = delay as? D else {
                    return
                }
                await clock.advance(by: advance)
                completion()
            })
    }
}
