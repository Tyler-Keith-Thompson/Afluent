//
//  ReplaceNil.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation
extension Workers {
    struct ReplaceNil<Success: Sendable>: AsynchronousUnitOfWork {
        let state: TaskState<Success>

        init<U: AsynchronousUnitOfWork>(upstream: U, newValue: Success) where U.Success == Success? {
            state = TaskState {
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
    /// Replaces any `nil` values from the upstream `AsynchronousUnitOfWork` with the provided non-nil value.
    ///
    /// - Parameter value: The value to emit when the upstream emits `nil`.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that emits the specified value instead of `nil` when the upstream emits `nil`.
    public func replaceNil<S: Sendable>(with value: S) -> some AsynchronousUnitOfWork<S> where Success == S? {
        Workers.ReplaceNil<S>(upstream: self, newValue: value)
    }
}
