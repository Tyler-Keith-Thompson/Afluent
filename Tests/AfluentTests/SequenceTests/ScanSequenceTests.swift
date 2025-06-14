//
//  ScanSequenceTests.swift
//  Afluent
//
//  Created by Tyler Thompson on 6/14/25.
//

import Afluent
import Foundation
import Testing

struct ScanSequenceTests {
    @Test func scanAccumulatesValuesCorrectly() async throws {
        let input = [1, 2, 3, 4, 5].async
        let result = try await input
            .scan(0) { $0 + $1 }
            .collect()
            .first()
        
        try #expect(#require(result) == [1, 3, 6, 10, 15])
    }

    @Test func scanEmitsNoValuesOnEmptyUpstream() async throws {
        let input = [Int]().async
        let result = try await input
            .scan(100) { $0 + $1 }
            .collect()
            .first()

        try #expect(#require(result).isEmpty)
    }

    @Test func scanHandlesSingleElement() async throws {
        let input = [42].async
        let result = try await input
            .scan(10) { $0 * $1 }
            .collect()
            .first()

        try #expect(#require(result) == [420])
    }

    @Test func scanPropagatesErrors() async throws {
        enum TestError: Error { case boom }

        let stream = AsyncThrowingStream<Int, Error> { continuation in
            continuation.yield(1)
            continuation.yield(2)
            continuation.finish(throwing: TestError.boom)
        }

        let task = Task {
            try await stream
                .scan(0) { $0 + $1 }
                .collect()
                .first()
        }

        let result = await task.result
        #expect(throws: TestError.boom) { try result.get() }
    }

    @Test func scanSupportsCancellation() async throws {
        let stream = AsyncThrowingStream<Int, Error> { continuation in
            continuation.yield(1)
            continuation.yield(2)
            continuation.yield(3)
            // Delay finish to allow cancellation
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000)
                continuation.finish()
            }
        }

        let task = Task {
            try await stream
                .scan(0) { $0 + $1 }
                .collect()
                .first()
        }

        task.cancel()
        let result = await task.result
        #expect(throws: CancellationError.self) { try result.get() }
    }
}
