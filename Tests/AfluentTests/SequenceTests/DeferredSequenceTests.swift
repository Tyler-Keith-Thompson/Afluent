//
//  DeferredTests.swift
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

        let sent = Array(0...9)

        let sequence = Deferred {
            defer {
                shouldNotStartExpectation.fulfill()
                shouldStartExpectation.fulfill()
            }
            return AsyncStream(Int.self, { continuation in
                sent.forEach { continuation.yield($0) }
                continuation.finish()
            })
        }

        await fulfillment(of: [shouldNotStartExpectation], timeout: 0.01)

        var iterator = sequence.makeAsyncIterator()

        await fulfillment(of: [shouldStartExpectation], timeout: 0)

        var received: [Int] = []
        while let i = try await iterator.next() {
            received.append(i)
        }

        XCTAssertEqual(received, sent)
    }

    func testReturnsANewIteratorEachTime() async throws {
        let sent = Array(0...9)

        let sequence = Deferred {
            AsyncStream(Int.self, { continuation in
                sent.forEach { continuation.yield($0) }
                continuation.finish()
            })
        }

        @Sendable func iterate() async throws {
            var iterator = sequence.makeAsyncIterator()

            var received: [Int] = []
            while let i = try await iterator.next() {
                received.append(i)
            }

            XCTAssertEqual(received, sent)
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0...9 {
                group.addTask {
                    try await iterate()
                }
            }

            for try await _ in group { }
        }
    }

    func testChecksForCancellation() async throws {
        let sequence = Deferred<AsyncStream<Int>> { AsyncStream { _ in } }

        let task = Task {
            try await Task.sleep(nanoseconds: 1_000_000)
            for try await _ in sequence { }
        }
        task.cancel()

        let result: Result<Void, Error> = await {
            do {
                return .success(try await task.value)
            } catch {
                return .failure(error)
            }
        }()

        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertNotNil(error as? CancellationError)
        }
    }
}
