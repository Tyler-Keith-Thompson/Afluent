//
//  MaterializeSequenceTests.swift
//
//
//  Created by Tyler Thompson on 12/1/23.
//

import Afluent
import Foundation
import XCTest

@available(iOS 16, *)
final class MaterializeSequenceTests: XCTestCase {
    func testMaterializeCapturesSuccesses() async throws {
        let result = try await DeferredTask { 1 }
            .toAsyncSequence()
            .materialize()
            .first()

        if case .element(let val) = result {
            XCTAssertEqual(val, 1)
        } else {
            XCTFail("Expected element, got: \(String(describing: result))")
        }
    }

    func testMaterializeCapturesCompletion() async throws {
        let result = try await DeferredTask { 1 }
            .toAsyncSequence()
            .materialize()
            .dropFirst()
            .first()

        guard case .complete = result else {
            XCTFail("Expected completion, got: \(String(describing: result))")
            return
        }
    }

    func testMaterializeCapturesNonCancelErrors() async throws {
        let result = try await DeferredTask { throw URLError(.badURL) }
            .toAsyncSequence()
            .materialize()
            .first()

        if case .failure(let error) = result {
            XCTAssertEqual(error as? URLError, URLError(.badURL))
        } else {
            XCTFail("Expected failure, got: \(String(describing: result))")
        }
    }

    func testDematerializeWithError() async throws {
        let result = await Task {
            try await DeferredTask { throw URLError(.badURL) }
                .toAsyncSequence()
                .materialize()
                .dematerialize()
                .first()
        }.result

        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(error as? URLError, URLError(.badURL))
        }
    }

    func testDematerializeWithoutError() async throws {
        let result = try await DeferredTask { 1 }
            .toAsyncSequence()
            .materialize()
            .dematerialize()
            .first()

        XCTAssertEqual(result, 1)
    }

    func testMaterializeDoesNotInterfereWithCancellation() async throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] == "true")
        actor Test {
            var started = false
            var ended = false

            func start() { started = true }
            func end() { ended = true }
        }
        let test = Test()

        let exp = expectation(description: "thing happened")
        exp.isInverted = true
        let task = Task {
            try await DeferredTask {
                await test.start()
                try await Task.sleep(for: .milliseconds(10))
            }.map {
                await test.end()
                exp.fulfill()
            }
            .toAsyncSequence()
            .materialize()
            .first()
        }

        try await Task.sleep(for: .milliseconds(2))

        task.cancel()

        await fulfillment(of: [exp], timeout: 0.011)

        let started = await test.started
        let ended = await test.ended

        XCTAssert(started)
        XCTAssertFalse(ended)
    }
}
