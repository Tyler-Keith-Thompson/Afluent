//
//  DeferredSequenceTests.swift
//
//
//  Created by Annalise Mariottini on 12/20/23.
//

import Afluent
import Foundation
import XCTest

class DeferredTests: XCTestCase {
    func testUpstreamSequenceDefersExecutionUntilIteration() async throws {
        let shouldNotStartExpectation = expectation(description: "sequence not started")
        shouldNotStartExpectation.isInverted = true
        let shouldStartExpectation = expectation(description: "sequence started")

        let sent = Array(0 ... 9)

        let sequence = Deferred {
            defer {
                shouldNotStartExpectation.fulfill()
                shouldStartExpectation.fulfill()
            }
            return AsyncStream(Int.self) { continuation in
                sent.forEach { continuation.yield($0) }
                continuation.finish()
            }
        }

        var iterator = sequence.makeAsyncIterator()

        await fulfillment(of: [shouldNotStartExpectation], timeout: 0.01)

        var received = try [await iterator.next()]

        await fulfillment(of: [shouldStartExpectation], timeout: 0)

        while let i = try await iterator.next() {
            received.append(i)
        }

        XCTAssertEqual(received, sent)
    }

    func testReturnsANewIteratorEachTime() async throws {
        let sent = Array(0 ... 9)

        let sequence = Deferred {
            AsyncStream(Int.self) { continuation in
                sent.forEach { continuation.yield($0) }
                continuation.finish()
            }
        }

        @Sendable func iterate() async throws {
            var received: [Int] = []
            for try await i in sequence {
                received.append(i)
            }
            XCTAssertEqual(received, sent)
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0 ... 9 {
                group.addTask {
                    try await iterate()
                }
            }

            for try await _ in group { }
        }
    }

    func testCanRetryUpstreamSequence() async throws {
        enum Err: Error {
            case e1
        }

        var upstreamCount = 0
        let sequence = Deferred {
            AsyncThrowingStream(Int.self) { continuation in
                defer { upstreamCount += 1 }
                guard upstreamCount > 0 else {
                    continuation.yield(with: .failure(Err.e1))
                    return
                }
                continuation.finish()
            }
        }

        for try await _ in sequence.retry() { }

        XCTAssertEqual(upstreamCount, 2)
    }

    func testChecksForCancellation() async throws {
        let sequence = Deferred<AsyncStream<Int>> { AsyncStream { _ in } }

        let task = Task {
            for try await _ in sequence { }
        }
        task.cancel()

        let result: Result<Void, Error> = await {
            do {
                return try .success(await task.value)
            } catch {
                return .failure(error)
            }
        }()

        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertNotNil(error as? CancellationError)
        }
    }
}
