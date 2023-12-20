//
//  HandleEvents.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Foundation

extension Workers {
    actor HandleEvents<Upstream: AsynchronousUnitOfWork, Success: Sendable>: AsynchronousUnitOfWork where Upstream.Success == Success {
        let state = TaskState<Success>()
        let upstream: Upstream
        let receiveExecute: (() async throws -> Void)?
        let receiveOutput: ((Success) async throws -> Void)?
        let receiveError: ((Error) async throws -> Void)?
        let receiveCancel: (() async throws -> Void)?

        init(upstream: Upstream, @_inheritActorContext @_implicitSelfCapture receiveExecute: (() async throws -> Void)?, @_inheritActorContext @_implicitSelfCapture receiveOutput: ((Success) async throws -> Void)?, @_inheritActorContext @_implicitSelfCapture receiveError: ((Error) async throws -> Void)?, @_inheritActorContext @_implicitSelfCapture receiveCancel: (() async throws -> Void)?) {
            self.upstream = upstream
            self.receiveExecute = receiveExecute
            self.receiveOutput = receiveOutput
            self.receiveError = receiveError
            self.receiveCancel = receiveCancel
        }

        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation { [weak self] in
                guard let self else { throw CancellationError() }

                do {
                    try Task.checkCancellation()
                    try await receiveExecute?()
                    let val = try await self.upstream.operation()
                    try await self.receiveOutput?(val)
                    return val
                } catch {
                    if !(error is CancellationError) {
                        try await self.receiveError?(error)
                    } else {
                        try await self.receiveCancel?()
                    }
                    throw error
                }
            }
        }
    }
}

extension AsynchronousUnitOfWork {
    /// Adds side-effects to the receiving events of the upstream `AsynchronousUnitOfWork`.
    ///
    /// - Parameters:
    ///   - receiveExecute: A closure that is invoked immediately before the upstream is executed. The closure can throw errors.
    ///   - receiveOutput: A closure that is invoked when the upstream emits a successful output. The closure can throw errors.
    ///   - receiveError: A closure that is invoked when the upstream emits an error. The closure can throw errors.
    ///   - receiveCancel: A closure that is invoked when the unit of work is cancelled. The closure can throw errors.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that performs the side-effects for the specified receiving events.
    ///
    /// - Note: The returned `AsynchronousUnitOfWork` forwards all receiving events from the upstream unit of work.
    public func handleEvents(@_inheritActorContext @_implicitSelfCapture receiveExecute: (() async throws -> Void)? = nil, @_inheritActorContext @_implicitSelfCapture receiveOutput: ((Success) async throws -> Void)? = nil, @_inheritActorContext @_implicitSelfCapture receiveError: ((Error) async throws -> Void)? = nil, @_inheritActorContext @_implicitSelfCapture receiveCancel: (() async throws -> Void)? = nil) -> some AsynchronousUnitOfWork<Success> {
        Workers.HandleEvents(upstream: self, receiveExecute: receiveExecute, receiveOutput: receiveOutput, receiveError: receiveError, receiveCancel: receiveCancel)
    }
}
