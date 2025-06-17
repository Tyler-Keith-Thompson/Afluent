//
//  RetryAfterFlatMappingSequence.swift
//
//
//  Created by Tyler Thompson on 11/28/23.
//

import Atomics
import Foundation

extension AsyncSequences {
    public final actor RetryAfterFlatMapping<
        Upstream: AsyncSequence & Sendable, Downstream: AsyncSequence & Sendable,
        Strategy: RetryStrategy
    >: AsyncSequence, AsyncIteratorProtocol, Sendable
    where Upstream.Element == Downstream.Element, Upstream.Element: Sendable {
        public typealias Element = Upstream.Element
        private final class State: @unchecked Sendable {
            let lock = NSRecursiveLock()
            let upstream: Upstream
            let transform: @Sendable (Error) async throws -> Downstream

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
                }
                set {
                    lock.lock()
                    defer { lock.unlock() }
                    _iterator = newValue
                }
            }

            init(
                upstream: Upstream,
                transform: @Sendable @escaping (Error) async throws -> Downstream
            ) {
                self.upstream = upstream
                self.transform = transform
            }
        }

        private let state: State
        private let strategy: Strategy

        init(
            upstream: Upstream, strategy: Strategy,
            transform: @Sendable @escaping (Error) async throws -> Downstream
        ) {
            state = State(
                upstream: upstream,
                transform: transform)
            self.strategy = strategy
        }

        private nonisolated func advanceAndSet(iterator: Upstream.AsyncIterator) async throws
            -> Upstream.Element?
        {
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
                try error.throwIf(CancellationError.self)

                if try await strategy.handle(
                    error: error,
                    beforeRetry: {
                        for try await _ in try await state.transform($0) {}
                    })
                {
                    state.iterator = state.upstream.makeAsyncIterator()
                    return try await next()
                } else {
                    throw error
                }
            }
        }

        public nonisolated func makeAsyncIterator() -> RetryAfterFlatMapping<
            Upstream, Downstream, Strategy
        > { self }
    }

    public final actor RetryOnAfterFlatMapping<
        Upstream: AsyncSequence & Sendable, Failure: Error & Equatable,
        Downstream: AsyncSequence & Sendable, Strategy: RetryStrategy
    >: AsyncSequence, AsyncIteratorProtocol, Sendable
    where Upstream.Element == Downstream.Element, Upstream.Element: Sendable {
        public typealias Element = Upstream.Element
        private final class State: @unchecked Sendable {
            let lock = NSRecursiveLock()
            let upstream: Upstream
            let error: Failure
            let transform: @Sendable (Failure) async throws -> Downstream

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
                }
                set {
                    lock.lock()
                    defer { lock.unlock() }
                    _iterator = newValue
                }
            }

            init(
                upstream: Upstream, error: Failure,
                transform: @Sendable @escaping (Failure) async throws -> Downstream
            ) {
                self.upstream = upstream
                self.error = error
                self.transform = transform
            }
        }

        private let state: State
        private let strategy: Strategy

        init(
            upstream: Upstream, strategy: Strategy, error: Failure,
            transform: @Sendable @escaping (Failure) async throws -> Downstream
        ) {
            state = State(
                upstream: upstream,
                error: error,
                transform: transform)
            self.strategy = strategy
        }

        private nonisolated func advanceAndSet(iterator: Upstream.AsyncIterator) async throws
            -> Upstream.Element?
        {
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
                try error.throwIf(CancellationError.self)
                    .throwIf(not: state.error)

                if try await strategy.handle(
                    error: error,
                    beforeRetry: { err in
                        for try await _ in try await state.transform(err.throwIf(not: state.error))
                        {}
                    })
                {
                    state.iterator = state.upstream.makeAsyncIterator()
                    return try await next()
                } else {
                    throw error
                }
            }
        }

        public nonisolated func makeAsyncIterator() -> RetryOnAfterFlatMapping<
            Upstream, Failure, Downstream, Strategy
        > { self }
    }
    
    public final actor RetryOnCastAfterFlatMapping<
        Upstream: AsyncSequence & Sendable, Failure: Error,
        Downstream: AsyncSequence & Sendable, Strategy: RetryStrategy
    >: AsyncSequence, AsyncIteratorProtocol, Sendable
    where Upstream.Element == Downstream.Element, Upstream.Element: Sendable {
        public typealias Element = Upstream.Element
        private final class State: @unchecked Sendable {
            let lock = NSRecursiveLock()
            let upstream: Upstream
            let error: Failure.Type
            let transform: @Sendable (Failure) async throws -> Downstream

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
                }
                set {
                    lock.lock()
                    defer { lock.unlock() }
                    _iterator = newValue
                }
            }

            init(
                upstream: Upstream, error: Failure.Type,
                transform: @Sendable @escaping (Failure) async throws -> Downstream
            ) {
                self.upstream = upstream
                self.error = error
                self.transform = transform
            }
        }

        private let state: State
        private let strategy: Strategy

        init(
            upstream: Upstream, strategy: Strategy, error: Failure.Type,
            transform: @Sendable @escaping (Failure) async throws -> Downstream
        ) {
            state = State(
                upstream: upstream,
                error: error,
                transform: transform)
            self.strategy = strategy
        }

        private nonisolated func advanceAndSet(iterator: Upstream.AsyncIterator) async throws
            -> Upstream.Element?
        {
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
                try error.throwIf(CancellationError.self)
                    .throwIf(not: state.error)

                if try await strategy.handle(
                    error: error,
                    beforeRetry: { err in
                        for try await _ in try await state.transform(err.throwIf(not: state.error))
                        {}
                    })
                {
                    state.iterator = state.upstream.makeAsyncIterator()
                    return try await next()
                } else {
                    throw error
                }
            }
        }

        public nonisolated func makeAsyncIterator() -> RetryOnCastAfterFlatMapping<
            Upstream, Failure, Downstream, Strategy
        > { self }
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
    public func retry<D: AsyncSequence, S: RetryStrategy>(
        _ strategy: S, _ transform: @Sendable @escaping (Error) async throws -> D
    ) -> AsyncSequences.RetryAfterFlatMapping<Self, D, S> {
        AsyncSequences.RetryAfterFlatMapping(
            upstream: self, strategy: strategy, transform: transform)
    }

    /// Retries the upstream `AsyncSequence` up to a specified number of times while applying a transformation on error.
    ///
    /// - Parameters:
    ///   - retries: The maximum number of times to retry the upstream, defaulting to 1.
    ///   - transform: An async closure that takes the error from the upstream and returns a new `AsyncSequence`.
    ///
    /// - Returns: An `AsyncSequence` that emits the same output as the upstream but retries on failure up to the specified number of times, with the applied transformation.
    public func retry<D: AsyncSequence>(
        _ retries: UInt = 1, _ transform: @Sendable @escaping (Error) async throws -> D
    ) -> AsyncSequences.RetryAfterFlatMapping<Self, D, RetryByCountStrategy> {
        AsyncSequences.RetryAfterFlatMapping(
            upstream: self, strategy: .byCount(retries), transform: transform)
    }

    /// Retries the upstream `AsynchronousUnitOfWork` up to a specified number of times only when a specific error occurs, while applying a transformation on error.
    ///
    /// - Parameters:
    ///   - retries: The maximum number of times to retry the upstream, defaulting to 1.
    ///   - error: The specific error that should trigger a retry.
    ///   - transform: An async closure that takes the error from the upstream and returns a new `AsyncSequence`.
    ///
    /// - Returns: An `AsyncSequence` that emits the same output as the upstream but retries on the specified error up to the specified number of times, with the applied transformation.
    public func retry<D: AsyncSequence, E: Error & Equatable>(
        _ retries: UInt = 1, on error: E, _ transform: @Sendable @escaping (E) async throws -> D
    ) -> AsyncSequences.RetryOnAfterFlatMapping<Self, E, D, RetryByCountStrategy> {
        AsyncSequences.RetryOnAfterFlatMapping(
            upstream: self, strategy: .byCount(retries), error: error, transform: transform)
    }

    /// Retries the upstream `AsynchronousUnitOfWork` up to a specified number of times only when a specific error occurs, while applying a transformation on error.
    ///
    /// - Parameters:
    ///   - strategy: The strategy to use when retrying
    ///   - error: The specific error that should trigger a transform.
    ///   - transform: An async closure that takes the error from the upstream and returns a new `AsyncSequence`.
    ///
    /// - Returns: An `AsyncSequence` that emits the same output as the upstream but retries on the specified error up to the specified number of times, with the applied transformation.
    public func retry<D: AsyncSequence, E: Error & Equatable, S: RetryStrategy>(
        _ strategy: S, on error: E, _ transform: @Sendable @escaping (E) async throws -> D
    ) -> AsyncSequences.RetryOnAfterFlatMapping<Self, E, D, S> {
        AsyncSequences.RetryOnAfterFlatMapping(
            upstream: self, strategy: strategy, error: error, transform: transform)
    }
    
    /// Retries the upstream `AsynchronousUnitOfWork` up to a specified number of times only when a specific error occurs, while applying a transformation on error.
    ///
    /// - Parameters:
    ///   - retries: The maximum number of times to retry the upstream, defaulting to 1.
    ///   - error: The specific error that should trigger a retry if a cast succeeds.
    ///   - transform: An async closure that takes the error from the upstream and returns a new `AsyncSequence`.
    ///
    /// - Returns: An `AsyncSequence` that emits the same output as the upstream but retries on the specified error up to the specified number of times, with the applied transformation.
    public func retry<D: AsyncSequence, E: Error>(
        _ retries: UInt = 1, on error: E.Type, _ transform: @Sendable @escaping (E) async throws -> D
    ) -> AsyncSequences.RetryOnCastAfterFlatMapping<Self, E, D, RetryByCountStrategy> {
        AsyncSequences.RetryOnCastAfterFlatMapping(
            upstream: self, strategy: .byCount(retries), error: error, transform: transform)
    }

    /// Retries the upstream `AsynchronousUnitOfWork` up to a specified number of times only when a specific error occurs, while applying a transformation on error.
    ///
    /// - Parameters:
    ///   - strategy: The strategy to use when retrying
    ///   - error: The specific error that should trigger a transform if a cast succeeds.
    ///   - transform: An async closure that takes the error from the upstream and returns a new `AsyncSequence`.
    ///
    /// - Returns: An `AsyncSequence` that emits the same output as the upstream but retries on the specified error up to the specified number of times, with the applied transformation.
    public func retry<D: AsyncSequence, E: Error, S: RetryStrategy>(
        _ strategy: S, on error: E.Type, _ transform: @Sendable @escaping (E) async throws -> D
    ) -> AsyncSequences.RetryOnCastAfterFlatMapping<Self, E, D, S> {
        AsyncSequences.RetryOnCastAfterFlatMapping(
            upstream: self, strategy: strategy, error: error, transform: transform)
    }
}
