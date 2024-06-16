//
//  RetryAfterFlatMappingSequence.swift
//
//
//  Created by Tyler Thompson on 11/28/23.
//

import Atomics
import Foundation

extension AsyncSequences {
    public final actor RetryAfterFlatMapping<Upstream: AsyncSequence & Sendable, Downstream: AsyncSequence & Sendable>: AsyncSequence, AsyncIteratorProtocol, Sendable where Upstream.Element == Downstream.Element, Upstream.Element: Sendable {
        public typealias Element = Upstream.Element
        private final class State: @unchecked Sendable {
            let lock = NSRecursiveLock()
            let upstream: Upstream
            let transform: @Sendable (Error) async throws -> Downstream
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

            init(upstream: Upstream, retries: UInt, transform: @escaping @Sendable (Error) async throws -> Downstream) {
                self.upstream = upstream
                self.retries = ManagedAtomic(retries)
                self.transform = transform
            }
        }

        private let state: State

        init(upstream: Upstream, retries: UInt, transform: @escaping @Sendable (Error) async throws -> Downstream) {
            state = State(upstream: upstream,
                          retries: retries,
                          transform: transform)
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
                    for try await _ in try await state.transform(error) { }
                    return try await next()
                } else {
                    throw error
                }
            }
        }

        public nonisolated func makeAsyncIterator() -> RetryAfterFlatMapping<Upstream, Downstream> { self }
    }

    public final actor RetryOnAfterFlatMapping<Upstream: AsyncSequence & Sendable, Failure: Error & Equatable, Downstream: AsyncSequence & Sendable>: AsyncSequence, AsyncIteratorProtocol, Sendable where Upstream.Element == Downstream.Element, Upstream.Element: Sendable {
        public typealias Element = Upstream.Element
        private final class State: @unchecked Sendable {
            let lock = NSRecursiveLock()
            let upstream: Upstream
            let error: Failure
            let transform: @Sendable (Failure) async throws -> Downstream
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

            init(upstream: Upstream, retries: UInt, error: Failure, transform: @escaping @Sendable (Failure) async throws -> Downstream) {
                self.upstream = upstream
                self.retries = ManagedAtomic(retries)
                self.error = error
                self.transform = transform
            }
        }

        private let state: State

        init(upstream: Upstream, retries: UInt, error: Failure, transform: @escaping @Sendable (Failure) async throws -> Downstream) {
            state = State(upstream: upstream,
                          retries: retries,
                          error: error,
                          transform: transform)
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
                    for try await _ in try await state.transform(unwrappedError) { }
                    return try await next()
                } else {
                    throw state.error
                }
            }
        }

        public nonisolated func makeAsyncIterator() -> RetryOnAfterFlatMapping<Upstream, Failure, Downstream> { self }
    }
}

extension AsyncSequence where Self: Sendable {
    /// Retries the upstream `AsyncSequence` up to a specified number of times while applying a transformation on error.
    ///
    /// - Parameters:
    ///   - retries: The maximum number of times to retry the upstream, defaulting to 1.
    ///   - transform: An async closure that takes the error from the upstream and returns a new `AsyncSequence`.
    ///
    /// - Returns: An `AsyncSequence` that emits the same output as the upstream but retries on failure up to the specified number of times, with the applied transformation.
    public func retry<D: AsyncSequence>(_ retries: UInt = 1, _ transform: @escaping @Sendable (Error) async throws -> D) -> AsyncSequences.RetryAfterFlatMapping<Self, D> {
        AsyncSequences.RetryAfterFlatMapping(upstream: self, retries: retries, transform: transform)
    }

    /// Retries the upstream `AsynchronousUnitOfWork` up to a specified number of times only when a specific error occurs, while applying a transformation on error.
    ///
    /// - Parameters:
    ///   - retries: The maximum number of times to retry the upstream, defaulting to 1.
    ///   - error: The specific error that should trigger a retry.
    ///   - transform: An async closure that takes the error from the upstream and returns a new `AsyncSequence`.
    ///
    /// - Returns: An `AsyncSequence` that emits the same output as the upstream but retries on the specified error up to the specified number of times, with the applied transformation.
    public func retry<D: AsyncSequence, E: Error & Equatable>(_ retries: UInt = 1, on error: E, _ transform: @escaping @Sendable (E) async throws -> D) -> AsyncSequences.RetryOnAfterFlatMapping<Self, E, D> {
        AsyncSequences.RetryOnAfterFlatMapping(upstream: self, retries: retries, error: error, transform: transform)
    }
}
