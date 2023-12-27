//
//  CancelTests.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Afluent
import ConcurrencyExtras
import Foundation
import XCTest

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
final class CancelTests: XCTestCase {
    func testDeferredTaskCancelledBeforeItStarts() async throws {
        let exp = expectation(description: "thing happened")
        exp.isInverted = true
        let task = DeferredTask { exp.fulfill() }
        task.cancel()
        let res = try await task.result
        XCTAssertThrowsError(try res.get())

        await fulfillment(of: [exp], timeout: 0.01)
    }

    func testDeferredTaskCancelledBeforeItEnds() async throws {
        try await withMainSerialExecutor {
            actor Test {
                var started = false
                var ended = false

                func start() { started = true }
                func end() { ended = true }
            }
            let test = Test()

            let exp = expectation(description: "thing happened")
            exp.isInverted = true
            let task = DeferredTask {
                await test.start()
                try await Task.sleep(for: .milliseconds(10))
            }.map {
                await test.end()
                exp.fulfill()
            }

            task.run()

            try await Task.sleep(for: .milliseconds(2))

            task.cancel()

            await fulfillment(of: [exp], timeout: 0.011)

            let started = await test.started
            let ended = await test.ended

            XCTAssert(started)
            XCTAssertFalse(ended)
        }
    }
}
