//
//  HandleEvents.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Foundation

extension Workers {
    struct HandleEvents<Success: Sendable>: AsynchronousUnitOfWork {
        let state: TaskState<Success>

        init<U: AsynchronousUnitOfWork>(upstream: U, receiveOutput: ((Success) async throws -> Void)?, receiveError: ((Error) async throws -> Void)?, receiveCancel: (() async throws -> Void)?) where U.Success == Success {
            state = TaskState {
                try await withTaskCancellationHandler {
                    do {
                        let val = try await upstream.operation()
                        try await receiveOutput?(val)
                        return val
                    } catch {
                        if !(error is CancellationError) {
                            try await receiveError?(error)
                        }
                        throw error
                    }
                } onCancel: {
                    if let receiveCancel {
                        Task { try await receiveCancel() }
                    }
                }
            }
        }
    }
}

extension AsynchronousUnitOfWork {
    /// Adds side-effects to the receiving events of the upstream `AsynchronousUnitOfWork`.
    ///
    /// - Parameters:
    ///   - receiveOutput: A closure that is invoked when the upstream emits a successful output. The closure can throw errors.
    ///   - receiveError: A closure that is invoked when the upstream emits an error. The closure can throw errors.
    ///   - receiveCancel: A closure that is invoked when the unit of work is cancelled. The closure can throw errors.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that performs the side-effects for the specified receiving events.
    ///
    /// - Note: The returned `AsynchronousUnitOfWork` forwards all receiving events from the upstream unit of work.
    public func handleEvents(receiveOutput: ((Success) async throws -> Void)? = nil, receiveError: ((Error) async throws -> Void)? = nil, receiveCancel: (() async throws -> Void)? = nil) -> some AsynchronousUnitOfWork<Success> {
        Workers.HandleEvents(upstream: self, receiveOutput: receiveOutput, receiveError: receiveError, receiveCancel: receiveCancel)
    }
}
