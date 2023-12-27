//
//  SubscriptionTests.swift
//
//
//  Created by Tyler Thompson on 10/30/23.
//

import Afluent
import ConcurrencyExtras
import Foundation
import XCTest

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
final class SubscriptionTests: XCTestCase {
    var set = Set<AnyCancellable>()
    var collection = [AnyCancellable]()

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

            let subscription = task.subscribe()

            try await Task.sleep(for: .milliseconds(2))

            subscription.cancel()

            await fulfillment(of: [exp], timeout: 0.011)

            let started = await test.started
            let ended = await test.ended

            XCTAssert(started)
            XCTAssertFalse(ended)
        }
    }

    func testDeferredTaskCancelledViaDeinitialization() async throws {
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

            var subscription: AnyCancellable? = task.subscribe()
            noop(subscription)

            try await Task.sleep(for: .milliseconds(2))

            subscription = nil

            await fulfillment(of: [exp], timeout: 0.011)

            let started = await test.started
            let ended = await test.ended

            XCTAssert(started)
            XCTAssertFalse(ended)
        }
    }

    func testDeferredTaskCancelledViaDeinitialization_WhenStoredInSet() async throws {
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
    }

    func testDeferredTaskCancelledViaDeinitialization_WhenStoredInCollection() async throws {
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

    // MARK: AsyncSequence

    func testAsyncSequenceCancelledBeforeItEnds() async throws {
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
            let sequence = AsyncStream<Void> { continuation in
                Task {
                    await test.start()
                    try await Task.sleep(for: .milliseconds(10))
                    continuation.yield()
                }
            }.map {
                await test.end()
                exp.fulfill()
            }

            let subscription = sequence.sink()

            try await Task.sleep(for: .milliseconds(2))

            subscription.cancel()

            await fulfillment(of: [exp], timeout: 0.011)

            let started = await test.started
            let ended = await test.ended

            XCTAssert(started)
            XCTAssertFalse(ended)
        }
    }

    func testAsyncSequenceCancelledViaDeinitialization() async throws {
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
            let sequence = AsyncStream<Void> { continuation in
                Task {
                    await test.start()
                    try await Task.sleep(for: .milliseconds(10))
                    continuation.yield()
                }
            }.map {
                await test.end()
                exp.fulfill()
            }

            var subscription: AnyCancellable? = sequence.sink()
            noop(subscription)

            try await Task.sleep(for: .milliseconds(2))

            subscription = nil

            await fulfillment(of: [exp], timeout: 0.011)

            let started = await test.started
            let ended = await test.ended

            XCTAssert(started)
            XCTAssertFalse(ended)
        }
    }

    func testAsyncSequenceCancelledViaDeinitialization_WhenStoredInSet() async throws {
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
            let sequence = AsyncStream<Void> { continuation in
                Task {
                    await test.start()
                    try await Task.sleep(for: .milliseconds(10))
                    continuation.yield()
                }
            }.map {
                await test.end()
                exp.fulfill()
            }

            sequence.sink()
                .store(in: &set)

            try await Task.sleep(for: .milliseconds(2))

            set.removeAll()

            await fulfillment(of: [exp], timeout: 0.011)

            let started = await test.started
            let ended = await test.ended

            XCTAssert(started)
            XCTAssertFalse(ended)
        }
    }

    func testAsyncSequenceCancelledViaDeinitialization_WhenStoredInCollection() async throws {
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
            let sequence = AsyncStream<Void> { continuation in
                Task {
                    await test.start()
                    try await Task.sleep(for: .milliseconds(10))
                    continuation.yield()
                }
            }.map {
                await test.end()
                exp.fulfill()
            }

            sequence.sink()
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

    func testAsyncSequenceReceivesCompletionWhenCancelled() async throws {
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
            let sequence = AsyncThrowingStream<Void, Error> { continuation in
                Task {
                    await test.start()
                    try await Task.sleep(for: .milliseconds(10))
                    continuation.yield()
                }
            }.map {
                await test.end()
                exp.fulfill()
            }

            let completedChannel = SingleValueChannel<Void>()
            let outputExp = expectation(description: "output received")
            outputExp.isInverted = true

            let subscription = sequence.sink { completion in
                switch completion {
                    case .finished: break
                    case .failure(let error): XCTFail("Unexpected error \(error)")
                }
                try? await completedChannel.send()
            } receiveOutput: {
                outputExp.fulfill()
            }

            try await Task.sleep(for: .milliseconds(2))

            subscription.cancel()

            try await completedChannel.execute()

            await fulfillment(of: [exp, outputExp], timeout: 0.011)

            let started = await test.started
            let ended = await test.ended

            XCTAssert(started)
            XCTAssertFalse(ended)
        }
    }

    func testAsyncSequenceReceivesCompletionWhenStreamCompletes() async throws {
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
            let sequence = AsyncThrowingStream<Void, Error> { continuation in
                Task {
                    await test.start()
                    continuation.finish()
                }
            }.map {
                await test.end()
                exp.fulfill()
            }

            let completedChannel = SingleValueChannel<Void>()
            let outputExp = expectation(description: "output received")
            outputExp.isInverted = true

            let subscription = sequence.sink { completion in
                switch completion {
                    case .finished: break
                    case .failure(let error): XCTFail("Unexpected error \(error)")
                }
                try? await completedChannel.send()
            } receiveOutput: {
                outputExp.fulfill()
            }
            noop(subscription)

            try await completedChannel.execute()

            await fulfillment(of: [exp, outputExp], timeout: 0.011)

            let started = await test.started
            let ended = await test.ended

            XCTAssert(started)
            XCTAssertFalse(ended)
        }
    }

    func testAsyncSequenceReceivesOutputThenCompletionWhenCancelled() async throws {
        try await withMainSerialExecutor {
            actor Test {
                var started = false
                var ended = false

                func start() { started = true }
                func end() { ended = true }
            }
            let test = Test()

            let exp = expectation(description: "thing happened")
            let sequence = AsyncStream<Void> { continuation in
                Task {
                    await test.start()
                    continuation.yield()
                }
            }.map {
                await test.end()
                exp.fulfill()
            }

            let completedChannel = SingleValueChannel<Void>()
            let outputExp = expectation(description: "output received")

            let subscription = sequence.sink { completion in
                switch completion {
                    case .finished: break
                    case .failure(let error): XCTFail("Unexpected error \(error)")
                }
                try? await completedChannel.send()
            } receiveOutput: {
                outputExp.fulfill()
            }

            try await Task.sleep(for: .milliseconds(2))

            subscription.cancel()

            try await completedChannel.execute()

            await fulfillment(of: [exp, outputExp], timeout: 0.011)

            let started = await test.started
            let ended = await test.ended

            XCTAssert(started)
            XCTAssert(ended)
        }
    }

    func testAsyncSequenceReceivesErrorInCompletion() async throws {
        try await withMainSerialExecutor {
            actor Test {
                var started = false
                var ended = false

                func start() { started = true }
                func end() { ended = true }
            }
            let test = Test()

            enum Err: Error, Equatable { case e1 }

            let exp = expectation(description: "thing happened")
            exp.isInverted = true
            let sequence = AsyncThrowingStream<Void, Error> { continuation in
                Task {
                    await test.start()
                    continuation.yield(with: .failure(Err.e1))
                }
            }.map {
                await test.end()
                exp.fulfill()
            }

            let completedChannel = SingleValueChannel<Void>()
            let outputExp = expectation(description: "output received")
            outputExp.isInverted = true

            let subscription = sequence.sink { completion in
                switch completion {
                    case .finished: XCTFail("Unexpected normal finish")
                    case .failure(let error): XCTAssertEqual(error as? Err, .e1)
                }
                try? await completedChannel.send()
            } receiveOutput: {
                outputExp.fulfill()
            }

            try await Task.sleep(for: .milliseconds(2))

            subscription.cancel()

            try await completedChannel.execute()

            await fulfillment(of: [exp, outputExp], timeout: 0.011)

            let started = await test.started
            let ended = await test.ended

            XCTAssert(started)
            XCTAssertFalse(ended)
        }
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension SubscriptionTests {
    func noop(_: Any?) { }
}
