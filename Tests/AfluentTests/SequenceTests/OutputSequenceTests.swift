//
//  OutputSequenceTests.swift
//  Afluent
//
//  Created by Roman Temchenko on 2025-03-07.
//

@testable import Afluent
import Foundation
import Testing
import ConcurrencyExtras

struct OutputSequenceTests {
    
    @Test func testOutputAt() async throws {
        let originalSequence = [0, 3, 5].async
        let result = try await originalSequence.output(at: 1).collect().first()
        #expect(result == [3])
    }
    
    @Test func testOutputAtWithEmptySequence() async throws {
        let emptySequence = [Int]().async
        let result = try await emptySequence.output(at: 0).first()
        try #require(result == nil)
    }
    
    @Test func testOutputAtOutOfBounds() async throws {
        let originalSequence = [0, 3, 5].async
        let result = try await originalSequence.output(at: 5).first()
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
        await Task.megaYield()
        
        continuation.finish(throwing: GeneralError.e1)
        
        let result = try await task.value
        #expect(result == nil)
    }
    
    @Test func testOutputIn() async throws {
        let originalSequence = [0, 3, 5, 7, 9].async
        let result = try await originalSequence.output(in: 1..<4).collect().first()
        #expect(result == [3, 5, 7])
    }
    
    @Test func testOutputInClosedRange() async throws {
        let originalSequence = [0, 3, 5, 7, 9].async
        let result = try await originalSequence.output(in: 1...3).collect().first()
        #expect(result == [3, 5, 7])
    }
    
    @Test func testOutputInPartialRangeUpTo() async throws {
        let originalSequence = [0, 3, 5, 7, 9].async
        let result = try await originalSequence.output(in: ..<3).collect().first()
        #expect(result == [0, 3, 5])
    }
    
    @Test func testOutputInPartialRangeThrough() async throws {
        let originalSequence = [0, 3, 5, 7, 9].async
        let result = try await originalSequence.output(in: ...3).collect().first()
        #expect(result == [0, 3, 5, 7])
    }
    
    @Test func testOutputInPartialRangeFrom() async throws {
        let originalSequence = [0, 3, 5, 7, 9].async
        let result = try await originalSequence.output(in: 2...).collect().first()
        #expect(result == [5, 7, 9])
    }
    
    @Test func testOutputInWithEmptySequence() async throws {
        let emptySequence = [Int]().async
        let result = try await emptySequence.output(in: 0...).first()
        try #require(result == nil)
    }
    
    @Test func testOutputInOutOfBounds() async throws {
        let originalSequence = [0, 3, 5].async
        let result = try await originalSequence.output(in: 5...).first()
        #expect(result == nil)
    }
    
    @Test func testOutputInCancellation() async throws {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: Int.self)
        
        let task = Task {
            let result = try await stream.output(in: 5...).first()
            #expect(result == nil)
            return result
        }
        
        continuation.yield(0)
        task.cancel()
        
        // Give task cancellation time to propagate.
        await Task.megaYield()
        
        continuation.finish(throwing: GeneralError.e1)
        
        let result = try await task.value
        #expect(result == nil)
    }
    
}
