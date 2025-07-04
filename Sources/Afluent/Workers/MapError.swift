//
//  MapError.swift
//
//
//  Created by Tyler Thompson on 11/2/23.
//

import Foundation

extension Workers {
    actor MapError<Upstream: AsynchronousUnitOfWork, Success: Sendable>: AsynchronousUnitOfWork
    where Success == Upstream.Success {
        let state = TaskState<Success>()
        let upstream: Upstream
        let transform: @Sendable (Error) -> Error

        init(upstream: Upstream, transform: @Sendable @escaping (Error) -> Error) {
            self.upstream = upstream
            self.transform = transform
        }

        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation { [weak self] in
                guard let self else { throw CancellationError() }

                do {
                    return try await self.upstream.operation()
                } catch {
                    guard !(error is CancellationError) else { throw error }

                    throw self.transform(error)
                }
            }
        }
    }
}

extension AsynchronousUnitOfWork {
    /// Transforms the error produced by the asynchronous unit of work.
    ///
    /// This function allows you to modify or replace the error produced by the current unit of work. It's useful for converting between error types or adding additional context to errors.
    ///
    /// ## Example
    /// ```
    /// enum MyError: Error { case network, wrapped(Error) }
    /// let task = DeferredTask { throw URLError(.notConnectedToInternet) }
    ///     .mapError { error in
    ///         MyError.wrapped(error) // wrap any error in your custom error type
    ///     }
    /// try await task.execute()
    /// ```
    ///
    /// - Parameter transform: A closure that takes the original error and returns a transformed error.
    ///
    /// - Returns: An asynchronous unit of work that produces the transformed error.
    ///
    /// - Note: The transform closure is called for any error thrown, except `CancellationError` which is propagated as is.
    public func mapError(_ transform: @Sendable @escaping (Error) -> Error)
        -> some AsynchronousUnitOfWork<Success>
    {
        Workers.MapError(upstream: self, transform: transform)
    }

    /// Transforms a specific error produced by the asynchronous unit of work.
    ///
    /// This function allows you to modify or replace a specific error produced by the current unit of work. If the error produced matches the provided error, the transform closure is applied; otherwise, the original error is propagated unchanged.
    ///
    /// ## Example
    /// ```
    /// enum MyError: Error, Equatable { case network, other }
    /// let task = DeferredTask { throw MyError.network }
    ///     .mapError(MyError.network) { error in
    ///         MyError.other // only transforms if error matches
    ///     }
    /// try await task.execute()
    /// ```
    ///
    /// - Parameters:
    ///   - error: The specific error to be transformed. This error is equatable, allowing for precise matching.
    ///   - transform: A closure that takes the matched error and returns a transformed error.
    ///
    /// - Returns: An asynchronous unit of work that produces either the transformed error (if a match was found) or the original error.
    ///
    /// - Note: Only errors equal to the specified error are transformed; others are propagated unchanged.
    public func mapError<E: Error & Equatable>(
        _ error: E, _ transform: @Sendable @escaping (Error) -> Error
    ) -> some AsynchronousUnitOfWork<Success> {
        mapError {
            if let e = $0 as? E, e == error { return transform(e) }
            return $0
        }
    }
}

