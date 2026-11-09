//
//  ZipTests.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Afluent
import Foundation
import Testing

struct ZipTests {
    @Test func zipCombinesTasks_WithExplicitFailure() async throws {
        let t1 = DeferredTask<Int> { 1 }

        let t2 = DeferredTask<String> { "A" }
        let t3 = t2.zip(t1)
        let val = try await t3.execute()  // Steak sauce!!!
        #expect(val.0 == "A")
        #expect(val.1 == 1)
    }

    @Test func zipCombinesTasks() async throws {
        let t1 = DeferredTask { 1 }

        let t2 = DeferredTask { "A" }
        let t3 = t2.zip(t1)
        let val = try await t3.execute()  // Steak sauce!!!
        #expect(val.0 == "A")
        #expect(val.1 == 1)
    }

    @Test func zipTransformCombinesTasks_WithExplicitFailure() async throws {
        let t1 = DeferredTask<Int> { 1 }

        let t2 = DeferredTask<String> { "A" }
        let t3 = t2.zip(t1) { $0 + String(describing: $1) }
        let val = try await t3.execute()  // Steak sauce!!!
        #expect(val == "A1")
    }

    @Test func zipTransformCombinesTasks() async throws {
        let t1 = DeferredTask { 1 }

        let t2 = DeferredTask { "A" }
        let t3 = t2.zip(t1) { $0 + String(describing: $1) }
        let val = try await t3.execute()  // Steak sauce!!!
        #expect(val == "A1")
    }

    @Test func zip3CombinesTasks_WithExplicitFailure() async throws {
        let t1 = DeferredTask<Int> { 1 }
        let t2 = DeferredTask<String> { "A" }
        let t3 = DeferredTask<Bool> { true }

        let t4 = t2.zip(t1, t3)
        let val = try await t4.execute()  // Steak sauce!!!
        #expect(val.0 == "A")
        #expect(val.1 == 1)
        #expect(val.2 == true)
    }

    @Test func zip3CombinesTasks() async throws {
        let t1 = DeferredTask { 1 }
        let t2 = DeferredTask { "A" }
        let t3 = DeferredTask { true }

        let t4 = t2.zip(t1, t3)
        let val = try await t4.execute()  // Steak sauce!!!
        #expect(val.0 == "A")
        #expect(val.1 == 1)
        #expect(val.2 == true)
    }

    @Test func zip3TransformCombinesTasks_WithExplicitFailure() async throws {
        let t1 = DeferredTask<Int> { 1 }
        let t2 = DeferredTask<String> { "A" }
        let t3 = DeferredTask<Bool> { true }

        let t4 = t2.zip(t1, t3) { $0 + String(describing: $1) + String(describing: $2) }
        let val = try await t4.execute()  // Steak sauce!!!
        #expect(val == "A1true")
    }

    @Test func zip3TransformCombinesTasks() async throws {
        let t1 = DeferredTask { 1 }
        let t2 = DeferredTask { "A" }
        let t3 = DeferredTask { true }

        let t4 = t2.zip(t1, t3) { $0 + String(describing: $1) + String(describing: $2) }
        let val = try await t4.execute()  // Steak sauce!!!
        #expect(val == "A1true")
    }

    @Test func zip4CombinesTasks_WithExplicitFailure() async throws {
        let t1 = DeferredTask<Int> { 1 }
        let t2 = DeferredTask<String> { "A" }
        let t3 = DeferredTask<Bool> { true }
        let t4 = DeferredTask<Character> { Character("!") }

        let t5 = t2.zip(t1, t3, t4)
        let val = try await t5.execute()  // Steak sauce!!!
        #expect(val.0 == "A")
        #expect(val.1 == 1)
        #expect(val.2 == true)
        #expect(val.3 == Character("!"))
    }

    @Test func zip4CombinesTasks() async throws {
        let t1 = DeferredTask { 1 }
        let t2 = DeferredTask { "A" }
        let t3 = DeferredTask { true }
        let t4 = DeferredTask { Character("!") }

        let t5 = t2.zip(t1, t3, t4)
        let val = try await t5.execute()  // Steak sauce!!!
        #expect(val.0 == "A")
        #expect(val.1 == 1)
        #expect(val.2 == true)
        #expect(val.3 == Character("!"))
    }

    @Test func zip4TransformCombinesTasks_WithExplicitFailure() async throws {
        let t1 = DeferredTask<Int> { 1 }
        let t2 = DeferredTask<String> { "A" }
        let t3 = DeferredTask<Bool> { true }
        let t4 = DeferredTask<Character> { Character("!") }

        let t5 = t2.zip(t1, t3, t4) {
            $0 + String(describing: $1) + String(describing: $2) + String(describing: $3)
        }
        let val = try await t5.execute()  // Steak sauce!!!
        #expect(val == "A1true!")
    }

    @Test func zip4TransformCombinesTasks() async throws {
        let t1 = DeferredTask { 1 }
        let t2 = DeferredTask { "A" }
        let t3 = DeferredTask { true }
        let t4 = DeferredTask { Character("!") }

        let t5 = t2.zip(t1, t3, t4) {
            $0 + String(describing: $1) + String(describing: $2) + String(describing: $3)
        }
        let val = try await t5.execute()  // Steak sauce!!!
        #expect(val == "A1true!")
    }
    @Test("zip throws the first side's error and cancels the other side", .timeLimit(.minutes(1)))
    func zipThrowsTheUpstreamsErrorAndCancelsTheDownstream() async throws {
        struct Failed: Error {}
        // Each other side waits on its own stream that never yields, so only cancellation ends it; it reports what it saw.
        let (neverYields0, neverYields0Continuation) = AsyncStream<Void>.makeStream()
        let (started, startedContinuation) = AsyncStream<Void>.makeStream()
        let (ended, endedContinuation) = AsyncStream<Bool>.makeStream()
        let waiting0 = DeferredTask {
            startedContinuation.yield()
            for await _ in neverYields0 {}
            endedContinuation.yield(Task.isCancelled)
            return 0
        }
        // Fails once the other sides are running, so each has work to cancel.
        let failing = DeferredTask<Int> {
            var running = 0
            for await _ in started {
                running += 1
                if running == 1 { break }
            }
            throw Failed()
        }
        let result = try await failing.zip(waiting0).result
        func getResult() throws { _ = try result.get() }
        #expect(throws: Failed.self, performing: getResult)
        var cancelled = [Bool]()
        for await value in ended {
            cancelled.append(value)
            if cancelled.count == 1 { break }
        }
        let expected = [true]
        #expect(cancelled == expected)
        neverYields0Continuation.finish()
    }

    @Test("zip throws the second side's error without waiting for the first side, and cancels it", .timeLimit(.minutes(1)))
    func zipThrowsTheDownstreamsErrorAndCancelsTheUpstream() async throws {
        struct Failed: Error {}
        // Each other side waits on its own stream that never yields, so only cancellation ends it; it reports what it saw.
        let (neverYields0, neverYields0Continuation) = AsyncStream<Void>.makeStream()
        let (started, startedContinuation) = AsyncStream<Void>.makeStream()
        let (ended, endedContinuation) = AsyncStream<Bool>.makeStream()
        let waiting0 = DeferredTask {
            startedContinuation.yield()
            for await _ in neverYields0 {}
            endedContinuation.yield(Task.isCancelled)
            return 0
        }
        // Fails once the other sides are running, so each has work to cancel.
        let failing = DeferredTask<Int> {
            var running = 0
            for await _ in started {
                running += 1
                if running == 1 { break }
            }
            throw Failed()
        }
        let result = try await waiting0.zip(failing).result
        func getResult() throws { _ = try result.get() }
        #expect(throws: Failed.self, performing: getResult)
        var cancelled = [Bool]()
        for await value in ended {
            cancelled.append(value)
            if cancelled.count == 1 { break }
        }
        let expected = [true]
        #expect(cancelled == expected)
        neverYields0Continuation.finish()
    }

    @Test("zip3 throws the last side's error without waiting for the others, and cancels them", .timeLimit(.minutes(1)))
    func zip3ThrowsTheLastSidesErrorAndCancelsTheOthers() async throws {
        struct Failed: Error {}
        // Each other side waits on its own stream that never yields, so only cancellation ends it; it reports what it saw.
        let (neverYields0, neverYields0Continuation) = AsyncStream<Void>.makeStream()
        let (neverYields1, neverYields1Continuation) = AsyncStream<Void>.makeStream()
        let (started, startedContinuation) = AsyncStream<Void>.makeStream()
        let (ended, endedContinuation) = AsyncStream<Bool>.makeStream()
        let waiting0 = DeferredTask {
            startedContinuation.yield()
            for await _ in neverYields0 {}
            endedContinuation.yield(Task.isCancelled)
            return 0
        }
        let waiting1 = DeferredTask {
            startedContinuation.yield()
            for await _ in neverYields1 {}
            endedContinuation.yield(Task.isCancelled)
            return 1
        }
        // Fails once the other sides are running, so each has work to cancel.
        let failing = DeferredTask<Int> {
            var running = 0
            for await _ in started {
                running += 1
                if running == 2 { break }
            }
            throw Failed()
        }
        let result = try await waiting0.zip(waiting1, failing).result
        func getResult() throws { _ = try result.get() }
        #expect(throws: Failed.self, performing: getResult)
        var cancelled = [Bool]()
        for await value in ended {
            cancelled.append(value)
            if cancelled.count == 2 { break }
        }
        let expected = [true, true]
        #expect(cancelled == expected)
        neverYields0Continuation.finish()
        neverYields1Continuation.finish()
    }

    @Test("zip4 throws the last side's error without waiting for the others, and cancels them", .timeLimit(.minutes(1)))
    func zip4ThrowsTheLastSidesErrorAndCancelsTheOthers() async throws {
        struct Failed: Error {}
        // Each other side waits on its own stream that never yields, so only cancellation ends it; it reports what it saw.
        let (neverYields0, neverYields0Continuation) = AsyncStream<Void>.makeStream()
        let (neverYields1, neverYields1Continuation) = AsyncStream<Void>.makeStream()
        let (neverYields2, neverYields2Continuation) = AsyncStream<Void>.makeStream()
        let (started, startedContinuation) = AsyncStream<Void>.makeStream()
        let (ended, endedContinuation) = AsyncStream<Bool>.makeStream()
        let waiting0 = DeferredTask {
            startedContinuation.yield()
            for await _ in neverYields0 {}
            endedContinuation.yield(Task.isCancelled)
            return 0
        }
        let waiting1 = DeferredTask {
            startedContinuation.yield()
            for await _ in neverYields1 {}
            endedContinuation.yield(Task.isCancelled)
            return 1
        }
        let waiting2 = DeferredTask {
            startedContinuation.yield()
            for await _ in neverYields2 {}
            endedContinuation.yield(Task.isCancelled)
            return 2
        }
        // Fails once the other sides are running, so each has work to cancel.
        let failing = DeferredTask<Int> {
            var running = 0
            for await _ in started {
                running += 1
                if running == 3 { break }
            }
            throw Failed()
        }
        let result = try await waiting0.zip(waiting1, waiting2, failing).result
        func getResult() throws { _ = try result.get() }
        #expect(throws: Failed.self, performing: getResult)
        var cancelled = [Bool]()
        for await value in ended {
            cancelled.append(value)
            if cancelled.count == 3 { break }
        }
        let expected = [true, true, true]
        #expect(cancelled == expected)
        neverYields0Continuation.finish()
        neverYields1Continuation.finish()
        neverYields2Continuation.finish()
    }

    @Test("zip with a transform that throws throws its error")
    func zipTransformThatThrowsThrowsItsError() async throws {
        struct Failed: Error {}
        let result = try await DeferredTask { 1 }
            .zip(DeferredTask { 2 }) { _, _ -> Int in throw Failed() }
            .result
        func getResult() throws { _ = try result.get() }
        #expect(throws: Failed.self, performing: getResult)
    }
}
