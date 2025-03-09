//
//  OutputSequenceTests.swift
//  Afluent
//
//  Created by Roman Temchenko on 2025-03-07.
//

import Afluent
import Foundation
import Testing

struct OutputSequenceTests {
    
    @Test func testOutputAt() async throws {
        let emptySequence = [0, 3, 5].async
        let result = try await emptySequence.output(at: 1).first()
        #expect(result == 3)
    }
    
    @Test func testOutputAtWithEmptySequence() async throws {
        let emptySequence = [Int]().async
        let result = try await emptySequence.output(at: 0).first()
        try #require(result == nil)
    }
    
    @Test func testOutputAtOutOfBounds() async throws {
        let emptySequence = [0, 3, 5].async
        let result = try await emptySequence.output(at: 5).first()
        #expect(result == nil)
    }
    
    @Test func testOutputAtWithSequenceThrowingError() async throws {
        let errorSequence = AsyncThrowingStream<Int, Error> { continuation in
            continuation.finish(throwing: GeneralError.e1)
        }
        await #expect(throws: GeneralError.e1, performing: {
            _ = try await errorSequence.output(at: 0).first()
        })
    }
    
    @Test func testOutputAtCancellation() async throws {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: Int.self)
        
        let task = Task {
            let result = try await stream.output(at: 4).first()
            #expect(result == nil)
            return result
        }
        
        continuation.yield(0)
        task.cancel()
        
        // Give task cancellation time to propagate.
        try await Task.sleep(for: .milliseconds(10))
        continuation.finish(throwing: GeneralError.e1)
        
        let result = try await task.value
        #expect(result == nil)
    }
    
}
