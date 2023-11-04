//
//  MapError.swift
//
//
//  Created by Tyler Thompson on 11/2/23.
//

import Foundation

extension Workers {
    struct MapError<Success: Sendable>: AsynchronousUnitOfWork {
        let state: TaskState<Success>
        init<U: AsynchronousUnitOfWork>(upstream: U, transform: @escaping (Error) -> Error) where Success == U.Success {
            state = TaskState {
                do {
                    return try await upstream.operation()
                } catch {
                    guard !(error is CancellationError) else { throw error }

                    throw transform(error)
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
    /// - Parameter transform: A closure that takes the original error and returns a transformed error.
    ///
    /// - Returns: An asynchronous unit of work that produces the transformed error.
    public func mapError(_ transform: @escaping (Error) -> Error) -> some AsynchronousUnitOfWork<Success> {
        Workers.MapError(upstream: self, transform: transform)
    }
}
