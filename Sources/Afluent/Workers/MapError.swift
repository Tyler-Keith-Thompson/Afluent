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
                    throw transform(error)
                }
            }
        }
    }
}

extension AsynchronousUnitOfWork {
    public func mapError(_ transform: @escaping (Error) -> Error) -> some AsynchronousUnitOfWork<Success> {
        Workers.MapError(upstream: self, transform: transform)
    }
}
