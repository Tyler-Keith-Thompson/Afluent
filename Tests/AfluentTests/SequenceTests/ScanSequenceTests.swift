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
        }

        // Start iterating only once the task is cancelled (cancellation ends this wait), so the elements can
        // never all be consumed first.
        let (gate, _) = AsyncStream<Void>.makeStream()
        let task = Task {
            for await _ in gate { break }
            let scanned = stream.scan(0) { $0 + $1 }
            return try await scanned.collect().first()
        }

        task.cancel()
        let result = await task.result
        #expect(throws: CancellationError.self) { try result.get() }
    }
}
