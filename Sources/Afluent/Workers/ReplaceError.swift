//
//  ReplaceError.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Foundation

extension Workers {
    struct ReplaceError<Upstream: AsynchronousUnitOfWork, Success: Sendable>: AsynchronousUnitOfWork
    where Upstream.Success == Success {
        let state = TaskState<Success>()
        let upstream: Upstream
        let newValue: Success

        init(upstream: Upstream, newValue: Success) {
            self.upstream = upstream
            self.newValue = newValue
        }

        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation {
                do {
                    return try await upstream.operation()
                } catch {
                    guard !(error is CancellationError) else { throw error }
                    return newValue
                }
            }
        }
    }
}

extension AsynchronousUnitOfWork {
    /// Replaces any error emitted by this unit of work with the provided value, allowing the operation to yield a fallback result instead of failing.
    ///
    /// Use this operator to recover from errors by substituting a default value, making the unit of work non-throwing for downstream consumers.
    ///
    /// ## Example
    /// ```swift
    /// enum MyError: Error { case network }
    /// let value = try await DeferredTask { throw MyError.network }
    ///     .replaceError(with: 0)
    ///     .execute()
    /// // value is 0 even if an error occurs upstream
    /// ```
    ///
    /// - Parameter value: The value to emit if an error occurs.
    /// - Returns: An `AsynchronousUnitOfWork` that emits the specified value if the upstream throws an error.
    /// - Note: Cancellation errors are always propagated and are not replaced.
    public func replaceError(with value: Success) -> some AsynchronousUnitOfWork<Success> {
        Workers.ReplaceError(upstream: self, newValue: value)
    }
}
