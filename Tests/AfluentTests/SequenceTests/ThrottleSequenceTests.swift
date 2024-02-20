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

@available(iOS 16.0, *)
final class ThrottleSequenceTests: XCTestCase {
    
    func testThrottleDoesNotThrottleUntilFirstValueIsReceived() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let stream = AsyncStream { continuation in
                DeferredTask { () }
                    .delay(for: .milliseconds(100))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(1)
                        continuation.finish()
                    })
                    .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: true)
            
            let task = Task {
                var elements = [Int]()
                
                for try await element in stream {
                    elements.append(element)
                }
                
                XCTAssertEqual(elements, [1])
            }
            
            await testClock.run()
            
            _ = await task.result
        }
    }
    
    func testThrottleDropsAllElementsExceptLast_whenElementsAreReceivedAllAtOnce_andLatestEqualTrue() async throws {
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
                
                XCTAssertEqual(elements, [10])
            }
            
            await testClock.run()
            
            _ = await task.result
        }
    }
    
    func testThrottleDropsAllElementsExceptFirst_whenElementsAreReceivedAllAtOnce_andLatestEqualFalse() async throws {
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
                
                XCTAssertEqual(elements, [1])
            }
            
            await testClock.run()
            
            _ = await task.result
        }
    }
    
    
    func testThrottleDoesNotDropElements_whenThrottledAtSameIntervalAsElementsAreReceived_andLatestEqualTrue() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let stream = AsyncStream { continuation in
                continuation.yield(1)
                DeferredTask { () }
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(2)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(3)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(4)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(5)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(6)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(7)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(8)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(9)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(10)
                        continuation.finish()
                    })
                    .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: true)
            
            let task = Task {
                var elements = [Int]()
                
                for try await element in stream {
                    elements.append(element)
                }
                
                XCTAssertEqual(elements, [1,2,3,4,5,6,7,8,9,10])
            }
            
            await testClock.run()
            
            _ = await task.result
        }
    }
    
    func testThrottleDoesNotDropElements_whenThrottledAtSameIntervalAsElementsAreReceived_andLatestEqualFalse() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let stream = AsyncStream { continuation in
                continuation.yield(1)
                DeferredTask { () }
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(2)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(3)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(4)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(5)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(6)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(7)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(8)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(9)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(10)
                        continuation.finish()
                    })
                    .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
            
            let task = Task {
                var elements = [Int]()
                
                for try await element in stream {
                    elements.append(element)
                }
                
                XCTAssertEqual(elements, [1,2,3,4,5,6,7,8,9,10])
            }
            
            await testClock.run()
            
            _ = await task.result
        }
    }
    
    func testThrottleDropsAllElementsExceptLastElement_whenThrottledAtDifferentIntervalThanElementsAreReceived_andLatestEqualTrue() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let stream = AsyncStream { continuation in
                continuation.yield(1)
                DeferredTask { () }
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(2)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(3)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(4)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(5)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(6)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(7)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(8)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(9)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(10)
                        continuation.finish()
                    })
                    .run()
            }.throttle(for: .milliseconds(20), clock: testClock, latest: true)
            
            let task = Task {
                var elements = [Int]()
                
                for try await element in stream {
                    elements.append(element)
                }
                
                XCTAssertEqual(elements, [1,2,4,6,8,10])
            }
            
            await testClock.run()
    
            _ = await task.result
            
        }
    }

    func testThrottleDropsAllElementsExceptFirstElement_whenThrottledAtDifferentIntervalThanElementsAreReceived_andLatestEqualFalse() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let stream = AsyncStream { continuation in
                continuation.yield(1)
                DeferredTask { () }
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(2)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(3)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(4)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(5)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(6)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(7)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(8)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(9)
                    })
                    .delay(for: .milliseconds(10))
                    .handleEvents(receiveOutput: { _ in
                        await testClock.advance(by: .milliseconds(10))
                        continuation.yield(10)
                        continuation.finish()
                    })
                    .run()
            }.throttle(for: .milliseconds(20), clock: testClock, latest: false)
            
            let task = Task {
                var elements = [Int]()
                
                for try await element in stream {
                    elements.append(element)
                }
                
                XCTAssertEqual(elements, [1,2,3,5,7,9])
            }
            
            await testClock.run()
    
            _ = await task.result
            
        }
    }
}
