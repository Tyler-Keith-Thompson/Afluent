//
//  SubscriptionTests.swift
//
//
//  Created by Tyler Thompson on 10/30/23.
//

import Afluent
import Foundation
import XCTest

@available(iOS 16, *)
final class SubscriptionTests: XCTestCase {
    var set = Set<AnyCancellable>()
    var collection = [AnyCancellable]()

    func testDeferredTaskCancelledBeforeItEnds() async throws {
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
        let task = DeferredTask {
            await test.start()
            try await Task.sleep(for: .milliseconds(10))
        }.map {
            await test.end()
            exp.fulfill()
        }

        let subscription = task.subscribe()

        try await Task.sleep(for: .milliseconds(2))

        subscription.cancel()

        await fulfillment(of: [exp], timeout: 0.011)

        let started = await test.started
        let ended = await test.ended

        XCTAssert(started)
        XCTAssertFalse(ended)
    }

    func testDeferredTaskCancelledViaDeinitialization() async throws {
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
        let task = DeferredTask {
            await test.start()
            try await Task.sleep(for: .milliseconds(10))
        }.map {
            await test.end()
            exp.fulfill()
        }

        var subscription: AnyCancellable? = task.subscribe()

        try await Task.sleep(for: .milliseconds(2))

        subscription = nil

        await fulfillment(of: [exp], timeout: 0.011)

        let started = await test.started
        let ended = await test.ended

        XCTAssert(started)
        XCTAssertFalse(ended)
    }

    func testDeferredTaskCancelledViaDeinitialization_WhenStoredInSet() async throws {
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
        let task = DeferredTask {
            await test.start()
            try await Task.sleep(for: .milliseconds(10))
        }.map {
            await test.end()
            exp.fulfill()
        }

        task.subscribe()
            .store(in: &set)

        try await Task.sleep(for: .milliseconds(2))

        set.removeAll()

        await fulfillment(of: [exp], timeout: 0.011)

        let started = await test.started
        let ended = await test.ended

        XCTAssert(started)
        XCTAssertFalse(ended)
    }

    func testDeferredTaskCancelledViaDeinitialization_WhenStoredInCollection() async throws {
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
        let task = DeferredTask {
            await test.start()
            try await Task.sleep(for: .milliseconds(10))
        }.map {
            await test.end()
            exp.fulfill()
        }

        task.subscribe()
            .store(in: &collection)

        try await Task.sleep(for: .milliseconds(2))

        collection.removeAll()

        await fulfillment(of: [exp], timeout: 0.011)

        let started = await test.started
        let ended = await test.ended

        XCTAssert(started)
        XCTAssertFalse(ended)
    }
}
