//
//  MaterializeSequenceTests.swift
//
//
//  Created by Tyler Thompson on 12/1/23.
//

import Afluent
import ConcurrencyExtras
import Foundation
import XCTest

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
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
        await withMainSerialExecutor {
            actor Test {
                var started = false
                var ended = false

                func start() { started = true }
                func end() { ended = true }
            }
            let test = Test()

            let exp = expectation(description: "thing happened")
            var task: Task<Void, Error>?
            task = Task {
                _ = try await DeferredTask {
                    await test.start()
                    task?.cancel()
                }
                .handleEvents(receiveCancel: {
                    exp.fulfill()
                })
                .map {
                    await test.end()
                }
                .toAsyncSequence()
                .materialize()
                .first()
            }

            await fulfillment(of: [exp], timeout: 0.01)

            let started = await test.started
            let ended = await test.ended

            XCTAssert(started)
            XCTAssertFalse(ended)
        }
    }
}
