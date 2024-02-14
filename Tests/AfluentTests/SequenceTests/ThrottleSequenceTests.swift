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
        let testClock = TestClock()
        
        await withMainSerialExecutor {
            let stream = AsyncStream { continuation in
                continuation.yield("1")
                DeferredTask {
                    "2"
                }
                .delay(for: .milliseconds(10))
                .handleEvents(receiveOutput: { output in
                    continuation.yield(output)
                })
                .run()
                DeferredTask {
                    "3"
                }
                .delay(for: .milliseconds(10))
                .handleEvents(receiveOutput: { output in
                    continuation.yield(output)
                    continuation.finish()
                })
                .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: true).collect()
            
            Task {
                for try await elements in stream {
                    XCTAssertEqual(elements, ["1","2","3"])
                }
            }
            
            await testClock.advance(by: .milliseconds(20))
        }
    }
    
    func testThrottleDoesNotDropElements_whenThrottledAtSameIntervalAsElementsAreReceived_andLatestEqualFalse() async throws {
        let testClock = TestClock()
        
        await withMainSerialExecutor {
            let stream = AsyncStream { continuation in
                continuation.yield("1")
                DeferredTask {
                    "2"
                }
                .delay(for: .milliseconds(10))
                .handleEvents(receiveOutput: { output in
                    continuation.yield(output)
                })
                .run()
                DeferredTask {
                    "3"
                }
                .delay(for: .milliseconds(10))
                .handleEvents(receiveOutput: { output in
                    continuation.yield(output)
                    continuation.finish()
                })
                .run()
            }.throttle(for: .milliseconds(10), clock: testClock, latest: false).collect()
            
            Task {
                for try await elements in stream {
                    XCTAssertEqual(elements, ["1","2","3"])
                }
            }
            
            await testClock.advance(by: .milliseconds(20))
        }
    }
    
    func testThrottleDropsAllElementsExceptLastElement_whenThrottledAtDifferentIntervalAsElementsAreReceived_andLatestEqualTrue() async throws {
        let testClock = TestClock()
        
        await withMainSerialExecutor {
            let stream = AsyncStream { continuation in
                continuation.yield("1")
                DeferredTask {
                    "2"
                }
                .delay(for: .milliseconds(10))
                .handleEvents(receiveOutput: { output in
                    continuation.yield(output)
                })
                .run()
                DeferredTask {
                    "3"
                }
                .delay(for: .milliseconds(10))
                .handleEvents(receiveOutput: { output in
                    continuation.yield(output)
                    continuation.finish()
                })
                .run()
            }.throttle(for: .milliseconds(20), clock: testClock, latest: true).collect()
            
            Task {
                for try await elements in stream {
                    XCTAssertEqual(elements, ["1", "3"])
                }
            }
        
            await testClock.advance(by: .milliseconds(20))
        }
    }
    
    func testThrottleDropsAllElementsExceptFirstElement_whenThrottledAtDifferentIntervalAsElementsAreReceived_andLatestEqualFalse() async throws {
        let testClock = TestClock()
        
        await withMainSerialExecutor {
            let stream = AsyncStream { continuation in
                continuation.yield("1")
                DeferredTask {
                    "2"
                }
                .delay(for: .milliseconds(10))
                .handleEvents(receiveOutput: { output in
                    continuation.yield(output)
                })
                .run()
                DeferredTask {
                    "3"
                }
                .delay(for: .milliseconds(10))
                .handleEvents(receiveOutput: { output in
                    continuation.yield(output)
                    continuation.finish()
                })
                .run()
            }.throttle(for: .milliseconds(20), clock: testClock, latest: false).collect()
            
            Task {
                for try await elements in stream {
                    XCTAssertEqual(elements, ["1", "2"])
                }
            }
        
            await testClock.advance(by: .milliseconds(20))
        }
    }
}
