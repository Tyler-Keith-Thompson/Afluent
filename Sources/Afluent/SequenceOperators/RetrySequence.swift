//
//  RetrySequence.swift
//
//
//  Created by Tyler Thompson on 11/28/23.
//

import Atomics
import Foundation

extension AsyncSequences {
    public final actor Retry<Upstream: AsyncSequence & Sendable, Strategy: RetryStrategy>:
        AsyncSequence, AsyncIteratorProtocol, Sendable
    where Upstream.Element: Sendable {
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
                }
                set {
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

    public final actor RetryOn<
        Upstream: AsyncSequence & Sendable, Failure: Error & Equatable, Strategy: RetryStrategy
    >: AsyncSequence, AsyncIteratorProtocol, Sendable where Upstream.Element: Sendable {
        public typealias Element = Upstream.Element
        private final class State: @unchecked Sendable {
            let lock = NSRecursiveLock()
            let upstream: Upstream
            let error: Failure

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

            init(upstream: Upstream, failure: Failure) {
                self.upstream = upstream
                error = failure
            }
        }

        private let state: State
        private let strategy: Strategy

        init(upstream: Upstream, strategy: Strategy, error: Failure) {
            state = State(
                upstream: upstream,
                failure: error)
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

                if try await strategy.handle(error: error) {
                    state.iterator = state.upstream.makeAsyncIterator()
                    return try await next()
                } else {
                    throw error
                }
            }
        }

        public nonisolated func makeAsyncIterator() -> RetryOn<Upstream, Failure, Strategy> { self }
    }
    
    public final actor RetryOnCast<
        Upstream: AsyncSequence & Sendable, Failure: Error, Strategy: RetryStrategy
    >: AsyncSequence, AsyncIteratorProtocol, Sendable where Upstream.Element: Sendable {
        public typealias Element = Upstream.Element
        private final class State: @unchecked Sendable {
            let lock = NSRecursiveLock()
            let upstream: Upstream
            let error: Failure.Type

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

            init(upstream: Upstream, failure: Failure.Type) {
                self.upstream = upstream
                error = failure
            }
        }

        private let state: State
        private let strategy: Strategy

        init(upstream: Upstream, strategy: Strategy, error: Failure.Type) {
            state = State(
                upstream: upstream,
                failure: error)
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

                if try await strategy.handle(error: error) {
                    state.iterator = state.upstream.makeAsyncIterator()
                    return try await next()
                } else {
                    throw error
                }
            }
        }

        public nonisolated func makeAsyncIterator() -> RetryOnCast<Upstream, Failure, Strategy> { self }
    }
}

extension AsyncSequence where Self: Sendable, Element: Sendable {
    /// Retries the upstream `AsyncSequence` using the provided retry strategy.
    ///
    /// This method returns an `AsyncSequence` which attempts to retry the upstream sequence according to the given retry strategy upon failure.
    ///
    /// Not all `AsyncSequence`s can be retried. For example, `AsyncStream` and `AsyncThrowingStream` cannot be retried on their own.
    ///
    /// ## Example
    /// ```
    /// actor CallCounter {
    ///     private(set) var count = 0
    ///     func increment() -> Int {
    ///         count += 1
    ///         return count
    ///     }
    /// }
    ///
    /// struct ExampleError: Error {}
    ///
    /// let counter = CallCounter()
    ///
    /// let sequence = DeferredTask {
    ///     let attempt = await counter.increment()
    ///     if attempt < 3 {
    ///         throw ExampleError()
    ///     }
    ///     return 42
    /// }
    /// .toAsyncSequence()
    /// .retry(.byCount(5))
    ///
    /// for try await value in sequence {
    ///     print(value) // prints 42 after retries
    /// }
    /// ```
    ///
    /// - Parameter strategy: The strategy to use when retrying.
    ///
    /// - Returns: An `AsyncSequence` that emits the same output as the upstream but retries on failure according to the provided strategy.
    /// - Important: Not every `AsyncSequence` can be retried, for this to work the sequence has to implement an iterator that doesn't preserve state across various creations.
    /// - Note: `AsyncStream` and `AsyncThrowingStream` are notable sequences which cannot be retried on their own.
    public func retry<S: RetryStrategy>(_ strategy: S) -> AsyncSequences.Retry<Self, S> {
        AsyncSequences.Retry(upstream: self, strategy: strategy)
    }

    /// Retries the upstream `AsyncSequence` up to a specified number of times.
    ///
    /// This method returns an `AsyncSequence` which retries the upstream sequence on any failure, up to the specified number of retries.
    ///
    /// Not all `AsyncSequence`s can be retried. For example, `AsyncStream` and `AsyncThrowingStream` cannot be retried on their own.
    ///
    /// ## Example
    /// ```
    /// actor CallCounter {
    ///     private(set) var count = 0
    ///     func increment() -> Int {
    ///         count += 1
    ///         return count
    ///     }
    /// }
    ///
    /// struct ExampleError: Error {}
    ///
    /// let counter = CallCounter()
    ///
    /// let sequence = DeferredTask {
    ///     let attempt = await counter.increment()
    ///     if attempt < 2 {
    ///         throw ExampleError()
    ///     }
    ///     return 100
    /// }
    /// .toAsyncSequence()
    /// .retry(3)
    ///
    /// for try await value in sequence {
    ///     print(value) // prints 100 after retries
    /// }
    /// ```
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
    /// This method returns an `AsyncSequence` that retries the upstream only when the specified error occurs, up to the given number of retries.
    ///
    /// Not all `AsyncSequence`s can be retried. For example, `AsyncStream` and `AsyncThrowingStream` cannot be retried on their own.
    ///
    /// ## Example
    /// ```
    /// actor CallCounter {
    ///     private(set) var count = 0
    ///     func increment() -> Int {
    ///         count += 1
    ///         return count
    ///     }
    /// }
    ///
    /// enum CustomError: Error, Equatable {
    ///     case temporaryFailure
    /// }
    ///
    /// let counter = CallCounter()
    ///
    /// let sequence = DeferredTask {
    ///     let attempt = await counter.increment()
    ///     if attempt < 2 {
    ///         throw CustomError.temporaryFailure
    ///     } else if attempt == 2 {
    ///         throw NSError(domain: "OtherError", code: 1, userInfo: nil)
    ///     }
    ///     return 7
    /// }
    /// .toAsyncSequence()
    /// .retry(3, on: CustomError.temporaryFailure)
    ///
    /// for try await value in sequence {
    ///     print(value) // prints 7 after retry
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - retries: The maximum number of times to retry the upstream, defaulting to 1.
    ///   - error: The specific error that should trigger a retry.
    ///
    /// - Returns: An `AsyncSequence` that emits the same output as the upstream but retries on the specified error up to the specified number of times.
    /// - Important: Not every `AsyncSequence` can be retried, for this to work the sequence has to implement an iterator that doesn't preserve state across various creations.
    /// - Note: `AsyncStream` and `AsyncThrowingStream` are notable sequences which cannot be retried on their own.
    public func retry<E: Error & Equatable>(_ retries: UInt = 1, on error: E)
        -> AsyncSequences.RetryOn<Self, E, RetryByCountStrategy>
    {
        AsyncSequences.RetryOn(upstream: self, strategy: .byCount(retries), error: error)
    }
    
    /// Retries the upstream `AsyncSequence` up to a specified number of times only when a specific error type is encountered.
    ///
    /// This method returns an `AsyncSequence` that retries the upstream only when an error can be cast to the specified error type, up to the given number of retries.
    ///
    /// Not all `AsyncSequence`s can be retried. For example, `AsyncStream` and `AsyncThrowingStream` cannot be retried on their own.
    ///
    /// ## Example
    /// ```
    /// actor CallCounter {
    ///     private(set) var count = 0
    ///     func increment() -> Int {
    ///         count += 1
    ///         return count
    ///     }
    /// }
    ///
    /// enum NetworkError: Error {
    ///     case timeout
    ///     case unknown
    /// }
    ///
    /// let counter = CallCounter()
    ///
    /// let sequence = DeferredTask {
    ///     let attempt = await counter.increment()
    ///     if attempt < 2 {
    ///         throw NetworkError.timeout
    ///     }
    ///     return 55
    /// }
    /// .toAsyncSequence()
    /// .retry(3, on: NetworkError.self)
    ///
    /// for try await value in sequence {
    ///     print(value) // prints 55 after retry on NetworkError.timeout
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - retries: The maximum number of times to retry the upstream, defaulting to 1.
    ///   - error: The specific error type that should trigger a retry if a cast succeeds.
    ///
    /// - Returns: An `AsyncSequence` that emits the same output as the upstream but retries on the specified error up to the specified number of times.
    /// - Important: Not every `AsyncSequence` can be retried, for this to work the sequence has to implement an iterator that doesn't preserve state across various creations.
    /// - Note: `AsyncStream` and `AsyncThrowingStream` are notable sequences which cannot be retried on their own.
    public func retry<E: Error>(_ retries: UInt = 1, on error: E.Type)
        -> AsyncSequences.RetryOnCast<Self, E, RetryByCountStrategy>
    {
        AsyncSequences.RetryOnCast(upstream: self, strategy: .byCount(retries), error: error)
    }
}

