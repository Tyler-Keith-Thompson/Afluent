//
//  RetryBehaviourTests.swift
//  Afluent
//

import Afluent
import Clocks
import ConcurrencyExtras
import Foundation
import Testing

struct RetryBehaviourTests {
    @Test("retry doesn't run its upstream again after the upstream throws CancellationError")
    func retryDoesNotRetryCancellation() async throws {
        let runs = LockIsolated(0)
        let work = DeferredTask {
            runs.withValue { $0 += 1 }
            throw CancellationError()
        }
        .retry(3)
        let result = try await work.result
        func getResult() throws { try result.get() }
        #expect(throws: CancellationError.self, performing: getResult)
        #expect(runs.value == 1)
    }

    @Test("retry(_:on:) throws a different error without consulting its strategy or running the side effect")
    func retryOnDoesNotConsultTheStrategyForADifferentError() async throws {
        struct Retried: Error, Equatable {}
        struct Other: Error, Equatable {}
        // A strategy that would retry forever, counting how often it is asked.
        actor CountingStrategy: RetryStrategy {
            var handled = 0
            func handle(error: Error, beforeRetry: @Sendable (Error) async throws -> Void) async throws -> Bool {
                handled += 1
                try await beforeRetry(error)
                return true
            }
        }
        let strategy = CountingStrategy()
        let runs = LockIsolated(0)
        let sideEffects = LockIsolated(0)
        let work = DeferredTask {
            runs.withValue { $0 += 1 }
            throw Other()
        }
        .retry(strategy, on: Retried()) { _ in
            DeferredTask { sideEffects.withValue { $0 += 1 } }
        }
        let result = try await work.result
        func getResult() throws { try result.get() }
        #expect(throws: Other.self, performing: getResult)
        #expect(runs.value == 1)
        #expect(sideEffects.value == 0)
        let handled = await strategy.handled
        #expect(handled == 0)
    }

    @Test("retry runs beforeRetry before each retry, and throws the error beforeRetry throws")
    func retryByCountStopsWithTheBeforeRetryError() async throws {
        struct Failed: Error {}
        struct BeforeRetryFailed: Error {}
        let strategy = RetryByCountStrategy(retryCount: 3)
        let calls = LockIsolated(0)
        func handle() async throws -> Bool {
            try await strategy.handle(error: Failed()) { _ in
                calls.withValue { $0 += 1 }
                throw BeforeRetryFailed()
            }
        }
        let result = await Task { try await handle() }.result
        func getResult() throws -> Bool { try result.get() }
        #expect(throws: BeforeRetryFailed.self, performing: getResult)
        #expect(calls.value == 1)
    }

    @Test("Sequence retry emits the elements sent before a failure again when it retries")
    func sequenceRetryReemitsElementsFromTheStart() async throws {
        struct Failed: Error {}
        let attempts = LockIsolated(0)
        let sequence = Deferred {
            AsyncThrowingStream<Int, any Error> { continuation in
                let attempt = attempts.withValue { $0 += 1; return $0 }
                continuation.yield(1)
                if attempt == 1 {
                    continuation.finish(throwing: Failed())
                } else {
                    continuation.yield(2)
                    continuation.finish()
                }
            }
        }
        .retry(1)
        var received = [Int]()
        for try await element in sequence { received.append(element) }
        let expected = [1, 1, 2]
        #expect(received == expected)
    }
}
