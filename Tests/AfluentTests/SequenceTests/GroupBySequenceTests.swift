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
    
    enum TestError: Error {
        case upstreamError
    }
    
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
                continuation.yield("d")
                continuation.yield("e")
                continuation.yield("f")
                continuation.yield("g")
                continuation.finish()
            }
                .groupBy { $0 }
                .map {
                    $0.key
                }
                .collect()
            
            let task = Task {
                let keys = try await stream.first()
                XCTAssertEqual(keys, ["a", "b", "c", "d", "e", "f", "g"])
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
                continuation.yield("d")
                continuation.yield("e")
                continuation.yield("f")
                continuation.yield("g")
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
                XCTAssertEqual(keys, ["A", "B", "C", "D", "E", "F", "G"])
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
                continuation.yield("d")
                continuation.yield("e")
                continuation.yield("f")
                continuation.yield("g")
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
                XCTAssertEqual(keys, ["a", "b", "c", "d", "e", "f", "g"])
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
                continuation.yield("d")
                continuation.yield("e")
                continuation.yield("f")
                continuation.yield("g")
                continuation.finish()
            }
                .groupBy { element in
                    return element
                }
            
            let task = Task {
                var results = [String: AsyncThrowingStream<String, Error>]()
                
                for try await sequence in stream {
                    results[sequence.key] = sequence.stream
                }
                
                let a = try await results["a"]?.collect().first()
                XCTAssertEqual(a, ["a"])
                
                let b = try await results["b"]?.collect().first()
                XCTAssertEqual(b, ["b"])
                
                let c = try await results["c"]?.collect().first()
                XCTAssertEqual(c, ["c", "c"])
                
                let d = try await results["d"]?.collect().first()
                XCTAssertEqual(d, ["d"])
                
                let e = try await results["e"]?.collect().first()
                XCTAssertEqual(e, ["e"])
                
                let f = try await results["f"]?.collect().first()
                XCTAssertEqual(f, ["f"])
                
                let g = try await results["g"]?.collect().first()
                XCTAssertEqual(g, ["g"])
            }
            
            _ = await task.result
        }
    }
        
        func testGroupByWithPopulatedSequenceGroupsByKeysWithSequences_throwingErrors() async throws {
            await withMainSerialExecutor {
                let stream = AsyncThrowingStream<String, Error> { continuation in
                    continuation.yield("a")
                    continuation.yield("b")
                    continuation.yield("c")
                    continuation.yield("c")
                    continuation.yield("d")
                    continuation.yield("e")
                    continuation.finish(throwing: TestError.upstreamError)
                    continuation.yield("f")
                    continuation.yield("g")
                    continuation.finish()
                }
                    .groupBy { element in
                        return element
                    }
                
                let task = Task {
                    var results = [String: AsyncThrowingStream<String, Error>]()
                    do {
                        for try await sequence in stream {
                            results[sequence.key] = sequence.stream
                        }
                        
                        let a = try await results["a"]?.collect().first()
                        XCTAssertEqual(a, ["a"])
                        
                        let b = try await results["b"]?.collect().first()
                        XCTAssertEqual(b, ["b"])
                        
                        let c = try await results["c"]?.collect().first()
                        XCTAssertEqual(c, ["c", "c"])
                        
                        let d = try await results["d"]?.collect().first()
                        XCTAssertEqual(d, ["d"])
                        
                        let e = try await results["e"]?.collect().first()
                        XCTAssertEqual(e, ["e"])
                        
                        let f = try await results["f"]?.collect().first()
                        XCTAssertNotEqual(f, ["f"])
                        
                        let g = try await results["g"]?.collect().first()
                        XCTAssertNotEqual(g, ["g"])
                    } catch  {
                        guard case TestError.upstreamError = error else {
                            XCTFail("No error thrown")
                            return
                        }
                    }
                }
                
                _ = await task.result
            }
    }
}
