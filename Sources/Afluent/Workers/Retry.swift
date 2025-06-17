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
    /// Retries the upstream `AsynchronousUnitOfWork` up to a specified number of times.
    ///
    /// - Parameter strategy: The retry strategy to use.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that emits the same output as the upstream but retries on failure up to the specified number of times.
    public func retry(_ strategy: some RetryStrategy) -> some AsynchronousUnitOfWork<Success> {
        Workers.Retry(upstream: self, strategy: strategy)
    }

    /// Retries the upstream `AsynchronousUnitOfWork` up to a specified number of times.
    ///
    /// - Parameter retries: The maximum number of times to retry the upstream, defaulting to 1.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that emits the same output as the upstream but retries on failure up to the specified number of times.
    public func retry(_ retries: UInt = 1) -> some AsynchronousUnitOfWork<Success> {
        Workers.Retry(upstream: self, strategy: .byCount(retries))
    }

    /// Retries the upstream `AsynchronousUnitOfWork` up to a specified number of times only when a specific error occurs.
    ///
    /// - Parameters:
    ///   - retries: The maximum number of times to retry the upstream, defaulting to 1.
    ///   - error: The specific error that should trigger a retry.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that emits the same output as the upstream but retries on the specified error up to the specified number of times.
    public func retry<E: Error & Equatable>(_ retries: UInt = 1, on error: E)
        -> some AsynchronousUnitOfWork<Success>
    {
        Workers.RetryOn(upstream: self, strategy: .byCount(retries), error: error)
    }
    
    /// Retries the upstream `AsynchronousUnitOfWork` up to a specified number of times only when a specific error occurs.
    ///
    /// - Parameters:
    ///   - retries: The maximum number of times to retry the upstream, defaulting to 1.
    ///   - error: The specific error that should trigger a retry after a successful cast.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that emits the same output as the upstream but retries on the specified error up to the specified number of times.
    public func retry<E: Error>(_ retries: UInt = 1, on error: E.Type)
        -> some AsynchronousUnitOfWork<Success>
    {
        Workers.RetryOnCast(upstream: self, strategy: .byCount(retries), error: error)
    }
}
