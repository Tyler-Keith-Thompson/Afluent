//
//  ReplaceError.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Foundation
extension Workers {
    struct ReplaceError<Success: Sendable>: AsynchronousUnitOfWork {
        let state: TaskState<Success>

        init<U: AsynchronousUnitOfWork>(upstream: U, newValue: Success) where U.Success == Success {
            state = TaskState {
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
    /// Replaces any errors from the upstream `AsynchronousUnitOfWork` with the provided value.
    ///
    /// - Parameter value: The value to emit upon encountering an error.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that emits the specified value instead of failing when the upstream fails.
    public func replaceError(with value: Success) -> some AsynchronousUnitOfWork<Success> {
        Workers.ReplaceError(upstream: self, newValue: value)
    }
}
