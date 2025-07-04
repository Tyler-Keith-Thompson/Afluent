//
//  ReplaceNil.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation

extension Workers {
    struct ReplaceNil<Upstream: AsynchronousUnitOfWork, Success: Sendable>: AsynchronousUnitOfWork
    where Upstream.Success == Success? {
        let state = TaskState<Success>()
        let upstream: Upstream
        let newValue: Success

        init(upstream: Upstream, newValue: Success) {
            self.upstream = upstream
            self.newValue = newValue
        }

        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation {
                if let val = try await upstream.operation() {
                    return val
                } else {
                    return newValue
                }
            }
        }
    }
}

extension AsynchronousUnitOfWork {
    /// Replaces any `nil` value emitted by this unit of work with the provided non-nil value.
    ///
    /// Use this operator to guarantee a non-optional result from an asynchronous unit of work that may emit `nil`.
    ///
    /// ## Example
    /// ```
    /// let result = try await DeferredTask { Int?.none }
    ///     .replaceNil(with: 42)
    ///     .execute()
    /// // result is 42 if the upstream produces nil
    /// ```
    ///
    /// - Parameter value: The value to emit when the upstream emits `nil`.
    /// - Returns: An `AsynchronousUnitOfWork` that emits the specified value instead of `nil`.
    /// - Note: Only `nil` values are replaced; non-nil values pass through unchanged.
    public func replaceNil<S: Sendable>(with value: S) -> some AsynchronousUnitOfWork<S>
    where Success == S? {
        Workers.ReplaceNil<Self, S>(upstream: self, newValue: value)
    }
}
