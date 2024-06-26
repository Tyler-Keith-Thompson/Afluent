//
//  RetryAfterFlatMapping.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Foundation

extension Workers {
    actor RetryAfterFlatMapping<Upstream: AsynchronousUnitOfWork, Downstream: AsynchronousUnitOfWork, Success>: AsynchronousUnitOfWork where Upstream.Success == Success {
        let state = TaskState<Success>()
        let upstream: Upstream
        var retryCount: UInt
        let transform: @Sendable (Error) async throws -> Downstream

        init(upstream: Upstream, retries: UInt, @_inheritActorContext @_implicitSelfCapture transform: @Sendable @escaping (Error) async throws -> Downstream) {
            self.upstream = upstream
            retryCount = retries
            self.transform = transform
        }

        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation { [weak self] in
                guard let self else { throw CancellationError() }

                guard await self.retryCount > 0 else {
                    return try await self.upstream._operation()()
                }

                while await self.retryCount > 0 {
                    do {
                        return try await self.upstream.operation()
                    } catch {
                        guard !(error is CancellationError) else { throw error }

                        _ = try await self.transform(error).operation()
                        await self.decrementRetry()
                        continue
                    }
                }

                return try await self.upstream.operation()
            }
        }

        func decrementRetry() {
            guard retryCount > 0 else { return }
            retryCount -= 1
        }
    }

    actor RetryOnAfterFlatMapping<Upstream: AsynchronousUnitOfWork, Downstream: AsynchronousUnitOfWork, Failure: Error & Equatable, Success>: AsynchronousUnitOfWork where Upstream.Success == Success {
        let state = TaskState<Success>()
        let upstream: Upstream
        var retryCount: UInt
        let error: Failure
        let transform: @Sendable (Failure) async throws -> Downstream

        init(upstream: Upstream, retries: UInt, error: Failure, @_inheritActorContext @_implicitSelfCapture transform: @Sendable @escaping (Failure) async throws -> Downstream) {
            self.upstream = upstream
            retryCount = retries
            self.error = error
            self.transform = transform
        }

        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation { [weak self] in
                guard let self else { throw CancellationError() }

                guard await self.retryCount > 0 else {
                    return try await self.upstream._operation()()
                }

                while await self.retryCount > 0 {
                    do {
                        return try await self.upstream.operation()
                    } catch (let err) {
                        guard !(err is CancellationError) else { throw err }

                        guard let unwrappedError = (err as? Failure),
                              unwrappedError == error else { throw err }
                        _ = try await self.transform(unwrappedError).operation()
                        await self.decrementRetry()
                        continue
                    }
                }
                return try await self.upstream.operation()
            }
        }

        func decrementRetry() {
            guard retryCount > 0 else { return }
            retryCount -= 1
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
        Workers.RetryAfterFlatMapping(upstream: self, retries: retries, transform: transform)
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
        Workers.RetryOnAfterFlatMapping(upstream: self, retries: retries, error: error, transform: transform)
    }
}
