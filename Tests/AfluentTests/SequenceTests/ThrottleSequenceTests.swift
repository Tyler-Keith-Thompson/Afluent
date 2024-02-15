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
    
    func testThrottleDoesNotDropElements_whenThrottledAtSameIntervalAsElementsAreReceived_andLatestEqualTrue() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let stream = AsyncStream { continuation in
                continuation.yield("1")
                DeferredTask { () }
                .delay(for: .milliseconds(10))
                .handleEvents(receiveOutput: { _ in
                    continuation.yield("2")
                })
                .delay(for: .milliseconds(10))
                .handleEvents(receiveOutput: { _ in
                    continuation.yield("3")
                })
                .handleEvents(receiveOutput: { _ in
                    continuation.finish()
                })
                .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: true)
            
            let task = Task {
                var elements = [String]()
                
                for try await element in stream {
                    elements.append(element)
                    await testClock.advance(by: .milliseconds(10))
                }
                
                XCTAssertEqual(elements, ["1","2","3"])
            }
        
            await testClock.run()
            
            _ = await task.result
        }
    }
    
    func testThrottleDoesNotDropElements_whenThrottledAtSameIntervalAsElementsAreReceived_andLatestEqualFalse() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let stream = AsyncStream { continuation in
                continuation.yield("1")
                DeferredTask { () }
                .delay(for: .milliseconds(10))
                .handleEvents(receiveOutput: { _ in
                    continuation.yield("2")
                })
                .delay(for: .milliseconds(10))
                .handleEvents(receiveOutput: { _ in
                    continuation.yield("3")
                    continuation.finish()
                })
                .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: false)
            
            let task = Task {
                var elements = [String]()
                
                for try await element in stream {
                    elements.append(element)
                    await testClock.advance(by: .milliseconds(10))
                }
                
                XCTAssertEqual(elements, ["1","2","3"])
            }
            
            await testClock.run()
            
            _ = await task.result
        }
    }
    
//    func testThrottleDropsAllElementsExceptLastElement_whenThrottledAtDifferentIntervalThanElementsAreReceived_andLatestEqualTrue() async throws {
//        await withMainSerialExecutor {    
//            let testClock = TestClock()
//            let stream = AsyncStream { continuation in
//                continuation.yield("1")
//                DeferredTask { () }
//                .delay(for: .milliseconds(10))
//                .handleEvents(receiveOutput: { _ in
//                    continuation.yield("2")
//                    await testClock.advance(by: .milliseconds(10))
//                })
//                .delay(for: .milliseconds(10))
//                .handleEvents(receiveOutput: { _ in
//                    continuation.yield("3")
//                    await testClock.advance(by: .milliseconds(10))
//                    continuation.finish()
//                })
//                .run()
//            }.throttle(for: .milliseconds(20), clock: testClock, latest: true)
//            
//            let task = Task {
//                var elements = [String]()
//                
//                for try await element in stream {
//                    elements.append(element)
//                }
//                
//                XCTAssertEqual(elements, ["1","3"])
//            }
//            
//            await testClock.advance(by: .milliseconds(20))
//    
//            _ = await task.result
//            
//        }
//    }

    func testThrottleDropsAllElementsExceptFirstElement_whenThrottledAtDifferentIntervalThanElementsAreReceived_andLatestEqualFalse() async throws {
        await withMainSerialExecutor {
            let testClock = TestClock()
            let stream = AsyncStream { continuation in
                continuation.yield("1")
                DeferredTask { () }
                .delay(for: .milliseconds(10))
                .handleEvents(receiveOutput: { _ in
                    continuation.yield("2")
                    await testClock.advance(by: .milliseconds(10))
                })
                .delay(for: .milliseconds(10))
                .handleEvents(receiveOutput: { _ in
                    continuation.yield("3")
                    await testClock.advance(by: .milliseconds(10))
                    continuation.finish()
                })
                .run()
            }.throttle(for: .milliseconds(20), clock: testClock, latest: false)
            
            let task = Task {
                var elements = [String]()
                
                for try await element in stream {
                    elements.append(element)
                }
                
                XCTAssertEqual(elements, ["1","2"])
            }
            
            await testClock.advance(by: .milliseconds(20))
    
            _ = await task.result
            
        }
    }
}
