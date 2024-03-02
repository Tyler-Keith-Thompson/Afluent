//
//  GroupBySequenceTests.swift
//
//
//  Created by Trip Phillips on 2/29/24.
//

import Foundation
import XCTest
import Afluent
import Clocks
import ConcurrencyExtras

final class GroupBySequenceTests: XCTestCase {
    func testGroupByWithEmptySequenceReturnsEmptyKeys() async throws {
        await withMainSerialExecutor {
            let stream = AsyncStream<String> { continuation in
                continuation.finish()
            }
                .groupBy { element in
                    return element.uppercased()
                }
                .map {
                    $0.key
                }
                .collect()
            
            let task = Task {
                let keys = try await stream.first()
                XCTAssert(keys?.isEmpty ?? true)
            }
            
            _ = await task.result
        }
    }
    
    func testGroupByWithEmptySequenceReturnsKeysWithoutTransformation() async throws {
        await withMainSerialExecutor {
            let stream = AsyncStream<String> { continuation in
                continuation.yield("a")
                continuation.yield("b")
                continuation.yield("c")
                continuation.finish()
            }
                .groupBy { $0 }
                .map {
                    $0.key
                }
                .collect()
            
            let task = Task {
                let keys = try await stream.first()
                XCTAssertEqual(keys, ["a", "b", "c"])
            }
            
            _ = await task.result
        }
    }
    
    func testGroupByWithEmptySequenceReturnsKeysWithTransformation() async throws {
        await withMainSerialExecutor {
            let stream = AsyncStream<String> { continuation in
                continuation.yield("a")
                continuation.yield("b")
                continuation.yield("c")
                continuation.finish()
            }
                .groupBy { element in
                    return element.uppercased()
                }
                .map {
                    $0.key
                }
                .collect()
            
            let task = Task {
                let keys = try await stream.first()
                XCTAssertEqual(keys, ["A", "B", "C"])
            }
            
            _ = await task.result
        }
    }
}
