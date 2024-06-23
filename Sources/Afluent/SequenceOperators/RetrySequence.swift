//
//  RetrySequence.swift
//
//
//  Created by Tyler Thompson on 11/28/23.
//

import Atomics
import Foundation

extension AsyncSequences {
    public final actor Retry<Upstream: AsyncSequence & Sendable>: AsyncSequence, AsyncIteratorProtocol, Sendable where Upstream.Element: Sendable {
        private final class State: @unchecked Sendable {
            let lock = NSRecursiveLock()
            let upstream: Upstream
            var retries: ManagedAtomic<UInt>

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

            init(upstream: Upstream, retries: UInt) {
                self.upstream = upstream
                self.retries = ManagedAtomic(retries)
            }
        }

        public typealias Element = Upstream.Element
        private let state: State

        init(upstream: Upstream, retries: UInt) {
            state = State(upstream: upstream, retries: retries)
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

                if state.retries.load(ordering: .sequentiallyConsistent) > 0 {
                    state.retries.wrappingDecrement(ordering: .sequentiallyConsistent)
                    state.iterator = state.upstream.makeAsyncIterator()
                    return try await next()
                } else {
                    throw error
                }
            }
        }

        public nonisolated func makeAsyncIterator() -> Retry<Upstream> { self }
    }

    public final actor RetryOn<Upstream: AsyncSequence & Sendable, Failure: Error & Equatable>: AsyncSequence, AsyncIteratorProtocol, Sendable where Upstream.Element: Sendable {
        public typealias Element = Upstream.Element
        private final class State: @unchecked Sendable {
            let lock = NSRecursiveLock()
            let upstream: Upstream
            let error: Failure
            var retries: ManagedAtomic<UInt>

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

            init(upstream: Upstream, retries: UInt, failure: Failure) {
                self.upstream = upstream
                self.retries = ManagedAtomic(retries)
                error = failure
            }
        }

        private let state: State

        init(upstream: Upstream, retries: UInt, error: Failure) {
            state = State(upstream: upstream,
                          retries: retries,
                          failure: error)
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
            } catch (let err) {
                guard !(err is CancellationError) else { throw err }

                guard let unwrappedError = (err as? Failure),
                      unwrappedError == state.error else {
                    throw err
                }
                if state.retries.load(ordering: .sequentiallyConsistent) > 0 {
                    state.retries.wrappingDecrement(ordering: .sequentiallyConsistent)
                    state.iterator = state.upstream.makeAsyncIterator()
                    return try await next()
                } else {
                    throw state.error
                }
            }
        }

        public nonisolated func makeAsyncIterator() -> RetryOn<Upstream, Failure> { self }
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
    public func retry(_ retries: UInt = 1) -> AsyncSequences.Retry<Self> {
        AsyncSequences.Retry(upstream: self, retries: retries)
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
    public func retry<E: Error & Equatable>(_ retries: UInt = 1, on error: E) -> AsyncSequences.RetryOn<Self, E> {
        AsyncSequences.RetryOn(upstream: self, retries: retries, error: error)
    }
}
