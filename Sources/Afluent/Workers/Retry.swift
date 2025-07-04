//
//  Retry.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation

extension Workers {
    actor Retry<Upstream: AsynchronousUnitOfWork, Success, Strategy: RetryStrategy>:
        AsynchronousUnitOfWork
    where Upstream.Success == Success {
        let state = TaskState<Success>()
        let upstream: Upstream
        var strategy: Strategy

        init(upstream: Upstream, strategy: Strategy) {
            self.upstream = upstream
            self.strategy = strategy
        }

        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation { [weak self] in
                guard let self else { throw CancellationError() }

                do {
                    return try await self.upstream._operation()()
                } catch {
                    var err = error
                    while try await strategy.handle(error: err) {
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

    actor RetryOn<
        Upstream: AsynchronousUnitOfWork, Failure: Error & Equatable, Success,
        Strategy: RetryStrategy
    >: AsynchronousUnitOfWork where Upstream.Success == Success {
        let state = TaskState<Success>()
        let upstream: Upstream
        let strategy: Strategy
        let error: Failure

        init(upstream: Upstream, strategy: Strategy, error: Failure) {
            self.upstream = upstream
            self.strategy = strategy
            self.error = error
        }

        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation { [weak self] in
                guard let self else { throw CancellationError() }
                do {
                    return try await self.upstream._operation()()
                } catch {
                    var err = error
                    while try await strategy.handle(error: err) {
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
    
    actor RetryOnCast<
        Upstream: AsynchronousUnitOfWork, Failure: Error, Success,
        Strategy: RetryStrategy
    >: AsynchronousUnitOfWork where Upstream.Success == Success {
        let state = TaskState<Success>()
        let upstream: Upstream
        let strategy: Strategy
        let error: Failure.Type

        init(upstream: Upstream, strategy: Strategy, error: Failure.Type) {
            self.upstream = upstream
            self.strategy = strategy
            self.error = error
        }

        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation { [weak self] in
                guard let self else { throw CancellationError() }
                do {
                    return try await self.upstream._operation()()
                } catch {
                    var err = error
                    while try await strategy.handle(error: err) {
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
    /// Retries this unit of work using the provided retry strategy.
    ///
    /// Use this operator to control retry behavior with custom or built-in strategies, mirroring the power and flexibility of the AsyncSequence retry operator.
    ///
    /// ## Example
    /// ```
    /// try await DeferredTask { try await fetchData() }
    ///     .retry(.byCount(3))
    ///     .execute()
    /// ```
    ///
    /// - Parameter strategy: The retry strategy to use.
    /// - Returns: An `AsynchronousUnitOfWork` that retries the operation according to the given strategy.
    public func retry(_ strategy: some RetryStrategy) -> some AsynchronousUnitOfWork<Success> {
        Workers.Retry(upstream: self, strategy: strategy)
    }

    /// Retries this unit of work up to the specified number of times on failure.
    ///
    /// ## Example
    /// ```
    /// try await DeferredTask { try await fetchData() }
    ///     .retry(3)
    ///     .execute()
    /// ```
    ///
    /// - Parameter retries: The maximum number of retry attempts (default is 1).
    /// - Returns: An `AsynchronousUnitOfWork` that retries on failure up to the specified times.
    public func retry(_ retries: UInt = 1) -> some AsynchronousUnitOfWork<Success> {
        Workers.Retry(upstream: self, strategy: .byCount(retries))
    }

    /// Retries this unit of work up to the specified number of times, but only when the error matches the given equatable error.
    ///
    /// ## Example
    /// ```
    /// enum NetworkError: Error, Equatable { case offline, timeout }
    /// try await DeferredTask { throw NetworkError.offline }
    ///     .retry(3, on: NetworkError.offline)
    ///     .execute()
    /// ```
    ///
    /// - Parameters:
    ///   - retries: The max number of retry attempts (default is 1).
    ///   - error: The specific error that triggers a retry.
    /// - Returns: An `AsynchronousUnitOfWork` that retries on the specified error up to the given count.
    public func retry<E: Error & Equatable>(_ retries: UInt = 1, on error: E)
        -> some AsynchronousUnitOfWork<Success>
    {
        Workers.RetryOn(upstream: self, strategy: .byCount(retries), error: error)
    }
    
    /// Retries this unit of work up to the specified number of times, but only when the error is of the given type.
    ///
    /// ## Example
    /// ```
    /// enum NetworkError: Error { case offline, timeout }
    /// try await DeferredTask { throw NetworkError.timeout }
    ///     .retry(3, on: NetworkError.self)
    ///     .execute()
    /// ```
    ///
    /// - Parameters:
    ///   - retries: The max number of retry attempts (default is 1).
    ///   - error: The error type that triggers a retry if a cast succeeds.
    /// - Returns: An `AsynchronousUnitOfWork` that retries on the specified error type up to the given count.
    public func retry<E: Error>(_ retries: UInt = 1, on error: E.Type)
        -> some AsynchronousUnitOfWork<Success>
    {
        Workers.RetryOnCast(upstream: self, strategy: .byCount(retries), error: error)
    }
}
