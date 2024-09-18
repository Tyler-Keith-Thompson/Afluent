//
//  RetryAfterFlatMapping.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Foundation

extension Workers {
    actor RetryAfterFlatMapping<Upstream: AsynchronousUnitOfWork, Downstream: AsynchronousUnitOfWork, Success, Strategy: RetryStrategy>: AsynchronousUnitOfWork where Upstream.Success == Success {
        let state = TaskState<Success>()
        let upstream: Upstream
        let strategy: Strategy
        let transform: @Sendable (Error) async throws -> Downstream

        init(upstream: Upstream, strategy: Strategy, @_inheritActorContext @_implicitSelfCapture transform: @Sendable @escaping (Error) async throws -> Downstream) {
            self.upstream = upstream
            self.strategy = strategy
            self.transform = transform
        }

        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation { [weak self] in
                guard let self else { throw CancellationError() }

                return try await self.strategy.handle(operation: self.upstream._operation(), beforeRetry: { _ = try await self.transform($0).operation() })
            }
        }
    }

    actor RetryOnAfterFlatMapping<Upstream: AsynchronousUnitOfWork, Downstream: AsynchronousUnitOfWork, Failure: Error & Equatable, Success, Strategy: RetryStrategy>: AsynchronousUnitOfWork where Upstream.Success == Success {
        let state = TaskState<Success>()
        let upstream: Upstream
        let strategy: Strategy
        let error: Failure
        let transform: @Sendable (Failure) async throws -> Downstream

        init(upstream: Upstream, strategy: Strategy, error: Failure, @_inheritActorContext @_implicitSelfCapture transform: @Sendable @escaping (Failure) async throws -> Downstream) {
            self.upstream = upstream
            self.strategy = strategy
            self.error = error
            self.transform = transform
        }

        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation { [weak self] in
                guard let self else { throw CancellationError() }

                return try await self.strategy.handle(operation: self.upstream._operation(), beforeRetry: { err in
                    guard let e = err as? Failure, e == self.error else { return }
                    _ = try await self.transform(e).operation()
                })
            }
        }
    }
}

extension AsynchronousUnitOfWork {
    /// Retries the upstream `AsynchronousUnitOfWork` up to a specified number of times while applying a transformation on error.
    ///
    /// - Parameters:
    ///   - retries: The maximum number of times to retry the upstream, defaulting to 1.
    ///   - transform: An async closure that takes the error from the upstream and returns a new `AsynchronousUnitOfWork`.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that emits the same output as the upstream but retries on failure up to the specified number of times, with the applied transformation.
    public func retry<D: AsynchronousUnitOfWork>(_ retries: UInt = 1, @_inheritActorContext @_implicitSelfCapture _ transform: @Sendable @escaping (Error) async throws -> D) -> some AsynchronousUnitOfWork<Success> {
        Workers.RetryAfterFlatMapping(upstream: self, strategy: .byCount(retries), transform: transform)
    }

    /// Retries the upstream `AsynchronousUnitOfWork` up to a specified number of times only when a specific error occurs, while applying a transformation on error.
    ///
    /// - Parameters:
    ///   - retries: The maximum number of times to retry the upstream, defaulting to 1.
    ///   - error: The specific error that should trigger a retry.
    ///   - transform: An async closure that takes the error from the upstream and returns a new `AsynchronousUnitOfWork`.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that emits the same output as the upstream but retries on the specified error up to the specified number of times, with the applied transformation.
    public func retry<D: AsynchronousUnitOfWork, E: Error & Equatable>(_ retries: UInt = 1, on error: E, @_inheritActorContext @_implicitSelfCapture _ transform: @Sendable @escaping (E) async throws -> D) -> some AsynchronousUnitOfWork<Success> {
        Workers.RetryOnAfterFlatMapping(upstream: self, strategy: RetryByCountOnErrorStrategy(retryCount: retries, error: error), error: error, transform: transform)
    }
}
