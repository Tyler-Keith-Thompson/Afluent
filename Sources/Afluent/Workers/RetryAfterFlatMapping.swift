//
//  RetryAfterFlatMapping.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Foundation

extension Workers {
    actor RetryAfterFlatMapping<
        Upstream: AsynchronousUnitOfWork, Downstream: AsynchronousUnitOfWork, Success,
        Strategy: RetryStrategy
    >: AsynchronousUnitOfWork where Upstream.Success == Success {
        let state = TaskState<Success>()
        let upstream: Upstream
        let strategy: Strategy
        let transform: @Sendable (Error) async throws -> Downstream

        init(
            upstream: Upstream, strategy: Strategy,
            @_inheritActorContext @_implicitSelfCapture transform: @Sendable @escaping (Error)
                async throws -> Downstream
        ) {
            self.upstream = upstream
            self.strategy = strategy
            self.transform = transform
        }

        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation { [weak self] in
                guard let self else { throw CancellationError() }

                do {
                    return try await self.upstream._operation()()
                } catch {
                    var err = error
                    while try await strategy.handle(
                        error: err, beforeRetry: { _ = try await self.transform($0).operation() })
                    {
                        do {
                            return try await self.upstream._operation()()
                        } catch {
                            err = error
                        }
                    }
                    throw err
                }
            }
        }
    }

    actor RetryOnAfterFlatMapping<
        Upstream: AsynchronousUnitOfWork, Downstream: AsynchronousUnitOfWork,
        Failure: Error & Equatable, Success, Strategy: RetryStrategy
    >: AsynchronousUnitOfWork where Upstream.Success == Success {
        let state = TaskState<Success>()
        let upstream: Upstream
        let strategy: Strategy
        let error: Failure
        let transform: @Sendable (Failure) async throws -> Downstream

        init(
            upstream: Upstream, strategy: Strategy, error: Failure,
            @_inheritActorContext @_implicitSelfCapture transform: @Sendable @escaping (Failure)
                async throws -> Downstream
        ) {
            self.upstream = upstream
            self.strategy = strategy
            self.error = error
            self.transform = transform
        }

        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation { [weak self] in
                guard let self else { throw CancellationError() }

                do {
                    return try await self.upstream._operation()()
                } catch {
                    var err = error
                    while try await strategy.handle(
                        error: err,
                        beforeRetry: { err in
                            guard let e = err as? Failure, e == self.error else { return }
                            _ = try await self.transform(e).operation()
                        })
                    {
                        try err.throwIf(CancellationError.self)
                            .throwIf(not: self.error)

                        do {
                            return try await self.upstream._operation()()
                        } catch {
                            err = error
                        }
                    }
                    throw err
                }
            }
        }
    }
    
    actor RetryOnCastAfterFlatMapping<
        Upstream: AsynchronousUnitOfWork, Downstream: AsynchronousUnitOfWork,
        Failure: Error, Success, Strategy: RetryStrategy
    >: AsynchronousUnitOfWork where Upstream.Success == Success {
        let state = TaskState<Success>()
        let upstream: Upstream
        let strategy: Strategy
        let error: Failure.Type
        let transform: @Sendable (Failure) async throws -> Downstream

        init(
            upstream: Upstream, strategy: Strategy, error: Failure.Type,
            @_inheritActorContext @_implicitSelfCapture transform: @Sendable @escaping (Failure)
                async throws -> Downstream
        ) {
            self.upstream = upstream
            self.strategy = strategy
            self.error = error
            self.transform = transform
        }

        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation { [weak self] in
                guard let self else { throw CancellationError() }

                do {
                    return try await self.upstream._operation()()
                } catch {
                    var err = error
                    while try await strategy.handle(
                        error: err,
                        beforeRetry: { err in
                            guard let e = err as? Failure else { return }
                            _ = try await self.transform(e).operation()
                        })
                    {
                        try err.throwIf(CancellationError.self)
                            .throwIf(not: self.error)

                        do {
                            return try await self.upstream._operation()()
                        } catch {
                            err = error
                        }
                    }
                    throw err
                }
            }
        }
    }
}

extension AsynchronousUnitOfWork {
    /// Retries this unit of work using the provided retry strategy, performing an asynchronous side effect with the error before each retry.
    ///
    /// This is useful for injecting retry-dependent side effects (such as refreshing tokens) before attempting another run.
    ///
    /// ## Example
    /// ```
    /// try await DeferredTask { try await fetchData() }
    ///     .retry(.byCount(3)) { error in
    ///         DeferredTask { try await refreshCredentials() }
    ///     }
    ///     .execute()
    /// ```
    ///
    /// - Parameters:
    ///   - strategy: The retry strategy to use.
    ///   - transform: An async closure run before each retry, returning a unit of work for side effects.
    /// - Returns: An `AsynchronousUnitOfWork` that performs the side effect before each retry.
    public func retry<D: AsynchronousUnitOfWork>(
        _ strategy: some RetryStrategy,
        @_inheritActorContext @_implicitSelfCapture _ transform: @Sendable @escaping (Error)
            async throws -> D
    ) -> some AsynchronousUnitOfWork<Success> {
        Workers.RetryAfterFlatMapping(upstream: self, strategy: strategy, transform: transform)
    }

    /// Retries this unit of work up to a specified number of times, running an async side effect before each retry.
    ///
    /// ## Example
    /// ```
    /// try await DeferredTask { try await fetchData() }
    ///     .retry(3) { error in
    ///         DeferredTask { try await refreshCredentials() }
    ///     }
    ///     .execute()
    /// ```
    ///
    /// - Parameters:
    ///   - retries: The max number of retry attempts (default 1).
    ///   - transform: An async closure run before each retry, returning a unit of work for side effects.
    /// - Returns: An `AsynchronousUnitOfWork` that performs the side effect before each retry.
    public func retry<D: AsynchronousUnitOfWork>(
        _ retries: UInt = 1,
        @_inheritActorContext @_implicitSelfCapture _ transform: @Sendable @escaping (Error)
            async throws -> D
    ) -> some AsynchronousUnitOfWork<Success> {
        Workers.RetryAfterFlatMapping(
            upstream: self, strategy: .byCount(retries), transform: transform)
    }

    /// Retries this unit of work up to the specified number of times only when the error matches, running an async side effect before retrying.
    ///
    /// ## Example
    /// ```
    /// enum NetworkError: Error, Equatable { case unauthorized }
    /// try await DeferredTask { throw NetworkError.unauthorized }
    ///     .retry(3, on: NetworkError.unauthorized) { _ in
    ///         DeferredTask { try await refreshToken() }
    ///     }
    ///     .execute()
    /// ```
    ///
    /// - Parameters:
    ///   - retries: The max number of retry attempts (default 1).
    ///   - error: The specific error to match for retry.
    ///   - transform: An async closure run before each retry, returning a unit of work for side effects.
    /// - Returns: An `AsynchronousUnitOfWork` that performs the side effect before retrying on the error.
    public func retry<D: AsynchronousUnitOfWork, E: Error & Equatable>(
        _ retries: UInt = 1, on error: E,
        @_inheritActorContext @_implicitSelfCapture _ transform: @Sendable @escaping (E)
            async throws -> D
    ) -> some AsynchronousUnitOfWork<Success> {
        Workers.RetryOnAfterFlatMapping(
            upstream: self, strategy: .byCount(retries), error: error, transform: transform)
    }

    /// Retries this unit of work up to the specified number of times only when the error matches, running an async side effect before retrying.
    ///
    /// ## Example
    /// ```
    /// enum NetworkError: Error, Equatable { case unauthorized }
    /// try await DeferredTask { throw NetworkError.unauthorized }
    ///     .retry(.byCount(3), on: NetworkError.unauthorized) { _ in
    ///         DeferredTask { try await refreshToken() }
    ///     }
    ///     .execute()
    /// ```
    ///
    /// - Parameters:
    ///   - strategy: The retry strategy to use.
    ///   - error: The specific error to match for retry.
    ///   - transform: An async closure run before each retry, returning a unit of work for side effects.
    /// - Returns: An `AsynchronousUnitOfWork` that performs the side effect before retrying on the error.
    public func retry<D: AsynchronousUnitOfWork, E: Error & Equatable, S: RetryStrategy>(
        _ strategy: S, on error: E,
        @_inheritActorContext @_implicitSelfCapture _ transform: @Sendable @escaping (E)
            async throws -> D
    ) -> some AsynchronousUnitOfWork<Success> {
        Workers.RetryOnAfterFlatMapping(
            upstream: self, strategy: strategy, error: error, transform: transform)
    }
    
    /// Retries this unit of work up to the specified number of times only when the error is of the given type, running an async side effect before retrying.
    ///
    /// ## Example
    /// ```
    /// enum NetworkError: Error { case unauthorized }
    /// try await DeferredTask { throw NetworkError.unauthorized }
    ///     .retry(3, on: NetworkError.self) { _ in
    ///         DeferredTask { try await refreshToken() }
    ///     }
    ///     .execute()
    /// ```
    ///
    /// - Parameters:
    ///   - retries: The max number of retry attempts (default 1).
    ///   - error: The error type to match for retry on cast.
    ///   - transform: An async closure run before each retry, returning a unit of work for side effects.
    /// - Returns: An `AsynchronousUnitOfWork` that performs the side effect before retrying on the error type.
    public func retry<D: AsynchronousUnitOfWork, E: Error>(
        _ retries: UInt = 1, on error: E.Type,
        @_inheritActorContext @_implicitSelfCapture _ transform: @Sendable @escaping (E)
            async throws -> D
    ) -> some AsynchronousUnitOfWork<Success> {
        Workers.RetryOnCastAfterFlatMapping(
            upstream: self, strategy: .byCount(retries), error: error, transform: transform)
    }

    /// Retries this unit of work up to the specified number of times only when the error is of the given type, running an async side effect before retrying.
    ///
    /// ## Example
    /// ```
    /// enum NetworkError: Error { case unauthorized }
    /// try await DeferredTask { throw NetworkError.unauthorized }
    ///     .retry(.byCount(3), on: NetworkError.self) { _ in
    ///         DeferredTask { try await refreshToken() }
    ///     }
    ///     .execute()
    /// ```
    ///
    /// - Parameters:
    ///   - strategy: The retry strategy to use.
    ///   - error: The error type to match for retry on cast.
    ///   - transform: An async closure run before each retry, returning a unit of work for side effects.
    /// - Returns: An `AsynchronousUnitOfWork` that performs the side effect before retrying on the error type.
    public func retry<D: AsynchronousUnitOfWork, E: Error, S: RetryStrategy>(
        _ strategy: S, on error: E.Type,
        @_inheritActorContext @_implicitSelfCapture _ transform: @Sendable @escaping (E)
            async throws -> D
    ) -> some AsynchronousUnitOfWork<Success> {
        Workers.RetryOnCastAfterFlatMapping(
            upstream: self, strategy: strategy, error: error, transform: transform)
    }
}

