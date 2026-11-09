//
//  CatchSequenceTests.swift
//
//
//  Created by Tyler Thompson on 11/28/23.
//

import Afluent
import ConcurrencyExtras
import Foundation
import Testing

struct CatchSequenceTests {
    @Test func testCatchDoesNotInterfereWithNoFailure() async throws {
        let val = try await DeferredTask { 1 }.toAsyncSequence()
            .catch { _ in DeferredTask { 2 }.toAsyncSequence() }
            .first()

        #expect(val == 1)
    }

    @Test func testCatchDoesNotThrowError() async throws {
        let val = await Task {
            try await DeferredTask { 1 }.toAsyncSequence()
                .map { _ -> Int in throw GeneralError.e1 }
                .catch { error in
                    #expect(error as? GeneralError == GeneralError.e1)
                    return DeferredTask { 2 }.toAsyncSequence()
                }
                .first()
        }.result

        try #expect(val.get() == 2)
    }

    @Test func testCatchSpecificError() async throws {
        enum Err: Error, Equatable {
            case e1
            case e2
        }

        let val = await Task {
            try await DeferredTask { 1 }.toAsyncSequence()
                .map { _ -> Int in throw Err.e1 }
                .catch(Err.e1) { error in
                    #expect(error == .e1)
                    return DeferredTask { 2 }.toAsyncSequence()
                }
                .first()
        }.result

        try #expect(val.get() == 2)
    }

    @Test func testCatchSpecificError_DoesNotCatchWrongError() async throws {
        enum Err: Error, Equatable {
            case e1
            case e2
        }

        let val = await Task {
            try await DeferredTask { 1 }.toAsyncSequence()
                .map { _ -> Int in throw Err.e2 }
                .catch(Err.e1) { error in
                    #expect(error == .e1)
                    return DeferredTask { 2 }.toAsyncSequence()
                }
                .first()
        }
        .result

        #expect { try val.get() } throws: { error in
            error as? Err == .e2
        }
    }

    @Test func testTryCatchDoesNotInterfereWithNoFailure() async throws {
        let val = try await DeferredTask { 1 }.toAsyncSequence()
            .tryCatch { _ in DeferredTask { 2 }.toAsyncSequence() }
            .first()

        #expect(val == 1)
    }

    @Test func testTryCatchDoesNotThrowError() async throws {
        let val = await Task {
            try await DeferredTask { 1 }.toAsyncSequence()
                .map { _ -> Int in throw GeneralError.e1 }
                .tryCatch { error in
                    #expect(error as? GeneralError == GeneralError.e1)
                    return DeferredTask { 2 }.toAsyncSequence()
                }
                .first()
        }
        .result

        try #expect(val.get() == 2)
    }

    @Test func testTryCatchSpecificError() async throws {
        enum Err: Error, Equatable {
            case e1
            case e2
        }

        let val = await Task {
            try await DeferredTask { 1 }.toAsyncSequence()
                .map { _ -> Int in throw Err.e1 }
                .tryCatch(Err.e1) { error in
                    #expect(error == .e1)
                    return DeferredTask { 2 }.toAsyncSequence()
                }
                .first()
        }
        .result

        try #expect(val.get() == 2)
    }

    @Test func testTryCatchSpecificError_DoesNotCatchWrongError() async throws {
        enum Err: Error, Equatable {
            case e1
            case e2
        }

        let val = await Task {
            try await DeferredTask { 1 }.toAsyncSequence()
                .map { _ -> Int in throw Err.e2 }
                .tryCatch(Err.e1) { error in
                    #expect(error == .e1)
                    return DeferredTask { 2 }.toAsyncSequence()
                }
                .first()
        }
        .result

        #expect { try val.get() } throws: { error in
            error as? Err == .e2
        }
    }

    @Test(
        "catch emits every element of a fallback whose iterator is a value type, then finishes",
        .timeLimit(.minutes(1)))
    func catchIteratesAValueTypeFallbackToItsEnd() async throws {
        struct Failed: Error {}
        // A struct iterator: an operator that advances a copy of it repeats the first element.
        struct Count: AsyncSequence {
            let end: Int
            struct AsyncIterator: AsyncIteratorProtocol {
                var next = 0
                let end: Int
                mutating func next() async -> Int? {
                    guard next < end else { return nil }
                    defer { next += 1 }
                    return next
                }
            }
            func makeAsyncIterator() -> AsyncIterator { AsyncIterator(end: end) }
        }
        let sequence = AsyncThrowingStream<Int, any Error> { $0.finish(throwing: Failed()) }
            .catch { _ in Count(end: 3) }
        var received = [Int]()
        // Bounded, so a repeating fallback fails rather than hangs.
        for try await element in sequence {
            received.append(element)
            if received.count > 10 { break }
        }
        let expected = [0, 1, 2]
        #expect(received == expected)
    }

    @Test("catch emits the upstream's elements before the failure, then the fallback's")
    func catchKeepsElementsSentBeforeTheFailure() async throws {
        struct Failed: Error {}
        let sequence = AsyncThrowingStream<Int, any Error> { continuation in
            continuation.yield(1)
            continuation.yield(2)
            continuation.finish(throwing: Failed())
        }
        .catch { _ in AsyncThrowingStream<Int, any Error> { continuation in
            continuation.yield(3)
            continuation.finish()
        } }
        var received = [Int]()
        for try await element in sequence { received.append(element) }
        let expected = [1, 2, 3]
        #expect(received == expected)
    }

    @Test("catch rethrows CancellationError rather than handing it to the handler")
    func catchDoesNotCatchCancellation() async throws {
        let handled = LockIsolated(false)
        let sequence = AsyncThrowingStream<Int, any Error> { $0.finish(throwing: CancellationError()) }
            .catch { _ in
                handled.setValue(true)
                return AsyncThrowingStream<Int, any Error> { $0.finish() }
            }
        let result = await Task { for try await _ in sequence {} }.result
        func getResult() throws { try result.get() }
        #expect(throws: CancellationError.self, performing: getResult)
        #expect(handled.value == false)
    }

    @Test("tryCatch throws the handler's error when the handler fails")
    func tryCatchThrowsTheHandlersError() async throws {
        struct Failed: Error {}
        struct HandlerFailed: Error {}
        let sequence = AsyncThrowingStream<Int, any Error> { $0.finish(throwing: Failed()) }
            .tryCatch { _ -> AsyncThrowingStream<Int, any Error> in throw HandlerFailed() }
        let result = await Task { for try await _ in sequence {} }.result
        func getResult() throws { try result.get() }
        #expect(throws: HandlerFailed.self, performing: getResult)
    }
}
