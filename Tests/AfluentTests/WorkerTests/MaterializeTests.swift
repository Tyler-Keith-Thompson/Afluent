//
//  MaterializeTests.swift
//
//
//  Created by Tyler Thompson on 11/3/23.
//

import Afluent
import ConcurrencyExtras
import Foundation
import XCTest

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
final class MaterializeTests: XCTestCase {
    func testMaterializeCapturesSuccesses() async throws {
        let result = try await DeferredTask {
            1
        }
        .materialize()
        .execute()

        XCTAssertEqual(try result.get(), 1)
    }

    func testMaterializeCapturesNonCancelErrors() async throws {
        let result = try await DeferredTask {
            throw URLError(.badURL)
        }
        .materialize()
        .execute()

        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(error as? URLError, URLError(.badURL))
        }
    }

    func testDematerializeWithError() async throws {
        let result = try await DeferredTask {
            throw URLError(.badURL)
        }
        .materialize()
        .dematerialize()
        .result

        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(error as? URLError, URLError(.badURL))
        }
    }

    func testDematerializeWithoutError() async throws {
        let result = try await DeferredTask {
            1
        }
        .materialize()
        .dematerialize()
        .execute()

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
            var task: AnyCancellable?
            task = DeferredTask {
                await test.start()
                task?.cancel()
            }
            .handleEvents(receiveCancel: {
                exp.fulfill()
            })
            .map {
                await test.end()
            }
            .materialize()
            .subscribe()

            await fulfillment(of: [exp], timeout: 0.011)

            let started = await test.started
            let ended = await test.ended

            XCTAssert(started)
            XCTAssertFalse(ended)
        }
    }
}
