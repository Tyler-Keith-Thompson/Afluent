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
    
    @Test func testOutputWithSequenceThrowingError() async throws {
        let errorSequence = AsyncThrowingStream<Int, Error> { continuation in
            continuation.finish(throwing: TestError.someError)
        }
        await #expect(throws: TestError.someError, performing: {
            _ = try await errorSequence.output(at: 0).first()
        })
    }
    
}
