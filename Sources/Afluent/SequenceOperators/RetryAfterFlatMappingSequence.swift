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
    /// Retries the upstream `AsyncSequence` using the provided retry strategy.
    ///
    /// The provided transformation closure is executed *before* each retry, allowing for side effects such as refreshing tokens or resetting state.
    /// The closure's returned `AsyncSequence` is always fully consumed before the retry occurs, but its elements are ignored.
    /// The element type of the returned sequence does not need to match the upstream's element type.
    ///
    /// This is useful for performing asynchronous side effects like credential refresh before retrying the main sequence.
    ///
    /// ## Example: Refreshing an access token on a 401 HTTP error before retrying the main request
    ///
    /// ```swift
    /// let mainRequest = URLSession.shared.dataTaskAsyncSequence(for: URLRequest(url: URL(string: "https://api.example.com/data")!))
    ///
    /// let retriedSequence = mainRequest.retry(.byCount(3)) { error in
    ///     // If error is 401 Unauthorized, refresh token before retrying
    ///     DeferredTask {
    ///         if let urlError = error as? URLError, urlError.code == .userAuthenticationRequired {
    ///             try await refreshAccessToken()
    ///         }
    ///     }
    ///     .toAsyncSequence() // This sequence is fully consumed before retrying, ignoring its elements
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - strategy: The retry strategy to use.
    ///   - transform: An async closure that takes the error from the upstream and returns a new `AsyncSequence` to be fully consumed for side effects before retrying.
    ///
    /// - Returns: An `AsyncSequence` that emits the same elements as the upstream but retries on failure using the given strategy,
    ///            performing the transformation before each retry.
    public func retry<D: AsyncSequence, S: RetryStrategy>(
        _ strategy: S, _ transform: @Sendable @escaping (Error) async throws -> D
    ) -> AsyncSequences.RetryAfterFlatMapping<Self, D, S> {
        AsyncSequences.RetryAfterFlatMapping(
            upstream: self, strategy: strategy, transform: transform)
    }

    /// Retries the upstream `AsyncSequence` up to a specified number of times.
    ///
    /// The transformation closure runs *before* each retry and can be used to perform side effects like refreshing credentials.
    /// The returned sequence is always fully consumed before retrying, and its element type does not need to match the upstream.
    ///
    /// This is useful for operations such as token refresh or cache reset prior to retrying the upstream sequence.
    ///
    /// ## Example: Refreshing tokens before retrying a network call
    ///
    /// ```swift
    /// let retriedSequence = myAsyncSequence.retry(3) { error in
    ///     DeferredTask {
    ///         if let authError = error as? MyAuthError {
    ///             try await refreshTokens()
    ///         }
    ///     }
    ///     .toAsyncSequence() // Fully consumed before retry
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - retries: The maximum number of retry attempts (default is 1).
    ///   - transform: An async closure executed before each retry, returning an `AsyncSequence` whose elements are ignored but fully consumed.
    ///
    /// - Returns: An `AsyncSequence` that retries on failure up to the specified number of times, performing the transformation before each retry.
    public func retry<D: AsyncSequence>(
        _ retries: UInt = 1, _ transform: @Sendable @escaping (Error) async throws -> D
    ) -> AsyncSequences.RetryAfterFlatMapping<Self, D, RetryByCountStrategy> {
        AsyncSequences.RetryAfterFlatMapping(
            upstream: self, strategy: .byCount(retries), transform: transform)
    }

    /// Retries the upstream `AsyncSequence` up to a specified number of times only when a specific error occurs.
    ///
    /// The transformation closure is executed *before* each retry on the specified error to perform side effects such as refreshing tokens or resetting state.
    /// The returned sequence is fully consumed before the retry and its element type does not need to match the upstream.
    ///
    /// This enables targeted retry behavior on specific errors with side effects executed prior to retrying.
    ///
    /// ## Example: Retry only on a specific error with side effect
    ///
    /// ```swift
    /// let retried = myAsyncSequence.retry(3, on: MyError.tokenExpired) { error in
    ///     DeferredTask {
    ///         try await refreshAuthToken()
    ///     }
    ///     .toAsyncSequence() // Fully consumed before retrying
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - retries: The maximum number of retry attempts (default is 1).
    ///   - error: The specific error to retry on.
    ///   - transform: An async closure executed before retrying on the specified error, returning an `AsyncSequence` fully consumed before retry.
    ///
    /// - Returns: An `AsyncSequence` that retries only on the specified error, running the transformation before each retry.
    public func retry<D: AsyncSequence, E: Error & Equatable>(
        _ retries: UInt = 1, on error: E, _ transform: @Sendable @escaping (E) async throws -> D
    ) -> AsyncSequences.RetryOnAfterFlatMapping<Self, E, D, RetryByCountStrategy> {
        AsyncSequences.RetryOnAfterFlatMapping(
            upstream: self, strategy: .byCount(retries), error: error, transform: transform)
    }

    /// Retries the upstream `AsyncSequence` with a custom retry strategy only on a specific error.
    ///
    /// The transformation closure runs *before* each retry if the error matches, for side effects such as refreshing tokens.
    /// The returned sequence's elements are ignored but the sequence is fully consumed before retrying.
    ///
    /// This is useful for applying custom retry strategies with side effects on specific error types.
    ///
    /// ## Example: Custom retry on error with side effect
    ///
    /// ```swift
    /// let retried = myAsyncSequence.retry(.byCount(3), on: MyError.tokenExpired) { error in
    ///     DeferredTask {
    ///         try await refreshAuthToken()
    ///     }
    ///     .toAsyncSequence() // Fully consumed before retry
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - strategy: The retry strategy to use.
    ///   - error: The specific error that triggers the retry and transformation.
    ///   - transform: The transformation executed before retrying on the error, producing a sequence fully consumed before retry.
    ///
    /// - Returns: An `AsyncSequence` retrying with the given strategy on the specified error.
    public func retry<D: AsyncSequence, E: Error & Equatable, S: RetryStrategy>(
        _ strategy: S, on error: E, _ transform: @Sendable @escaping (E) async throws -> D
    ) -> AsyncSequences.RetryOnAfterFlatMapping<Self, E, D, S> {
        AsyncSequences.RetryOnAfterFlatMapping(
            upstream: self, strategy: strategy, error: error, transform: transform)
    }
    
    /// Retries the upstream `AsyncSequence` up to a specified number of times only when an error can be cast to a specific type.
    ///
    /// The transformation closure executes *before* each retry if the error is of the specified type, allowing side effects such as refreshing tokens.
    /// The returned sequence is always fully consumed before retrying and its elements are ignored.
    ///
    /// This allows retrying only on errors castable to a given type, performing asynchronous side effects beforehand.
    ///
    /// ## Example: Retry on error cast with side effect
    ///
    /// ```swift
    /// let retried = myAsyncSequence.retry(3, on: MyError.self) { error in
    ///     DeferredTask {
    ///         try await refreshAuthToken()
    ///     }
    ///     .toAsyncSequence() // Fully consumed before retry
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - retries: The maximum retry attempts.
    ///   - error: The error type to match for retry and transformation.
    ///   - transform: The transformation executed before retrying when the cast succeeds, fully consuming its sequence.
    ///
    /// - Returns: An `AsyncSequence` that retries on errors castable to the specified type.
    public func retry<D: AsyncSequence, E: Error>(
        _ retries: UInt = 1, on error: E.Type, _ transform: @Sendable @escaping (E) async throws -> D
    ) -> AsyncSequences.RetryOnCastAfterFlatMapping<Self, E, D, RetryByCountStrategy> {
        AsyncSequences.RetryOnCastAfterFlatMapping(
            upstream: self, strategy: .byCount(retries), error: error, transform: transform)
    }

    /// Retries the upstream `AsyncSequence` with a custom strategy when the error is castable to a specific type.
    ///
    /// The transformation runs *before* each retry if the error cast succeeds, useful for side effects like refreshing tokens.
    /// The returned sequence is fully consumed before retrying, ignoring its elements.
    ///
    /// This enables retrying with custom strategy only when the error can be cast to the specified type,
    /// performing asynchronous side effects prior to retry.
    ///
    /// ## Example: Custom retry on casted error with side effect
    ///
    /// ```swift
    /// let retried = myAsyncSequence.retry(.byCount(3), on: MyError.self) { error in
    ///     DeferredTask {
    ///         try await refreshAuthToken()
    ///     }
    ///     .toAsyncSequence() // Fully consumed before retry
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - strategy: The retry strategy to apply.
    ///   - error: The error type to match via casting.
    ///   - transform: The transformation executed before retrying when the cast succeeds, fully consuming the returned sequence.
    ///
    /// - Returns: An `AsyncSequence` retrying with the given strategy only when the error can be cast to the specified type.
    public func retry<D: AsyncSequence, E: Error, S: RetryStrategy>(
        _ strategy: S, on error: E.Type, _ transform: @Sendable @escaping (E) async throws -> D
    ) -> AsyncSequences.RetryOnCastAfterFlatMapping<Self, E, D, S> {
        AsyncSequences.RetryOnCastAfterFlatMapping(
            upstream: self, strategy: strategy, error: error, transform: transform)
    }
}

