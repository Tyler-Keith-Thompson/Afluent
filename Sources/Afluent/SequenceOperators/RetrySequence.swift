//
//  RetrySequence.swift
//
//
//  Created by Tyler Thompson on 11/28/23.
//

import Atomics
import Foundation

extension AsyncSequences {
    public final actor Retry<Upstream: AsyncSequence & Sendable, Strategy: RetryStrategy>: AsyncSequence, AsyncIteratorProtocol, Sendable where Upstream.Element: Sendable {
        private final class State: @unchecked Sendable {
            let lock = NSRecursiveLock()
            let upstream: Upstream

            private var _iterator: Upstream.AsyncIterator?
            var iterator: Upstream.AsyncIterator {
                get {
                    lock.lock()
                    defer { lock.unlock() }
                    guard let _iterator else {
                        let val = upstream.makeAsyncIterator()
                        self._iterator = val
                        return val
                    }
                    return _iterator
                } set {
                    lock.lock()
                    defer { lock.unlock() }
                    _iterator = newValue
                }
            }

            init(upstream: Upstream) {
                self.upstream = upstream
            }
        }

        public typealias Element = Upstream.Element
        private let state: State
        let strategy: Strategy

        init(upstream: Upstream, strategy: Strategy) {
            state = State(upstream: upstream)
            self.strategy = strategy
        }

        private nonisolated func advanceAndSet(iterator: Upstream.AsyncIterator) async throws -> Upstream.Element? {
            var copy = iterator
            let next = try await copy.next()
            state.iterator = copy
            return next
        }

        public func next() async throws -> Upstream.Element? {
            do {
                try Task.checkCancellation()
                return try await advanceAndSet(iterator: state.iterator)
            } catch {
                guard !(error is CancellationError) else { throw error }

                if try await strategy.handle(error: error) {
                    state.iterator = state.upstream.makeAsyncIterator()
                    return try await next()
                } else {
                    throw error
                }
            }
        }

        public nonisolated func makeAsyncIterator() -> Retry<Upstream, Strategy> { self }
    }
}

extension AsyncSequence where Self: Sendable, Element: Sendable {
    /// Retries the upstream `AsyncSequence` up to a specified number of times.
    ///
    /// - Parameter retries: The maximum number of times to retry the upstream, defaulting to 1.
    ///
    /// - Returns: An `AsyncSequence` that emits the same output as the upstream but retries on failure up to the specified number of times.
    /// - Important: Not every `AsyncSequence` can be retried, for this to work the sequence has to implement an iterator that doesn't preserve state across various creations.
    /// - Note: `AsyncStream` and `AsyncThrowingStream` are notable sequences which cannot be retried on their own.
    public func retry(_ retries: UInt = 1) -> AsyncSequences.Retry<Self, RetryByCountStrategy> {
        AsyncSequences.Retry(upstream: self, strategy: .byCount(retries))
    }

    /// Retries the upstream `AsyncSequence` up to a specified number of times only when a specific error occurs.
    ///
    /// - Parameters:
    ///   - retries: The maximum number of times to retry the upstream, defaulting to 1.
    ///   - error: The specific error that should trigger a retry.
    ///
    /// - Returns: An `AsyncSequence` that emits the same output as the upstream but retries on the specified error up to the specified number of times.
    /// - Important: Not every `AsyncSequence` can be retried, for this to work the sequence has to implement an iterator that doesn't preserve state across various creations.
    /// - Note: `AsyncStream` and `AsyncThrowingStream` are notable sequences which cannot be retried on their own.
    public func retry<E: Error & Equatable>(_ retries: UInt = 1, on error: E) -> AsyncSequences.Retry<Self, RetryByCountOnErrorStrategy<E>> {
        AsyncSequences.Retry(upstream: self, strategy: RetryByCountOnErrorStrategy(retryCount: retries, error: error))
    }
}
