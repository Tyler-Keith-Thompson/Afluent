//
//  GroupBySequenceTests.swift
//
//
//  Created by Trip Phillips on 2/29/24.
//

import Foundation
import XCTest
@testable import Afluent
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
    
    func testGroupByWithPopulatedSequenceReturnsKeysWithoutTransformation() async throws {
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
    
    func testGroupByWithPopulatedSequenceReturnsKeysWithTransformation() async throws {
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
    
    func testGroupByWithPopulatedSequenceGroupsByKeys() async throws {
        await withMainSerialExecutor {
            let stream = AsyncStream<String> { continuation in
                continuation.yield("a")
                continuation.yield("b")
                continuation.yield("c")
                continuation.yield("c")
                continuation.finish()
            }
                .groupBy { element in
                    return element
                }
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
    
    func testGroupByWithPopulatedSequenceGroupsByKeysWithSequences() async throws {
        await withMainSerialExecutor {
            let stream = AsyncStream<String> { continuation in
                continuation.yield("a")
                continuation.yield("b")
                continuation.yield("c")
                continuation.yield("c")
                continuation.finish()
            }
                .groupBy { element in
                    return element
                }
            
            let task = Task {
                var results = [String: AsyncSequences.KeyedAsyncSequence<String, AsyncStream<String>>]()
                
                for try await sequence in stream {
                    results[sequence.key] = sequence
                }
                
                let a = try await results["a"]?.collect().first()
                XCTAssertEqual(a, ["a"])
                
                let b = try await results["b"]?.collect().first()
                XCTAssertEqual(b, ["b"])
                
                let c = try await results["c"]?.collect().first()
                XCTAssertEqual(c, ["c", "c"])
            }
            
            _ = await task.result
        }
    }
}
