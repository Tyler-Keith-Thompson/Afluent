//
//  Breakpoint.swift
//
//
//  Created by Tyler Thompson on 11/1/23.
//

import Foundation

extension AsynchronousUnitOfWork {
    /// Introduces a breakpoint into the asynchronous unit of work.
    ///
    /// This function allows you to introduce conditional breakpoints based on the output or error of the asynchronous operation.
    /// If the provided conditions are met, a `SIGTRAP` signal is raised, pausing execution in a debugger.
    ///
    /// - Parameters:
    ///   - receiveOutput: A closure that takes the successful output of the operation. If this closure returns `true`, a breakpoint is triggered. Default is `nil`.
    ///   - receiveError: A closure that takes any error produced by the operation. If this closure returns `true`, a breakpoint is triggered. Default is `nil`.
    ///
    /// - Returns: An asynchronous unit of work with the breakpoint conditions applied.
    @_transparent @_alwaysEmitIntoClient @inlinable public func breakpoint(receiveOutput: ((Success) async throws -> Bool)? = nil, receiveError: ((Error) async throws -> Bool)? = nil) -> some AsynchronousUnitOfWork<Success> {
        handleEvents(receiveOutput: { output in
            if try await receiveOutput?(output) == true {
                raise(SIGTRAP)
            }
        }, receiveError: { error in
            if try await receiveError?(error) == true {
                raise(SIGTRAP)
            }
        })
    }

    /// Introduces a breakpoint into the asynchronous unit of work when an error occurs.
    ///
    /// This function triggers a `SIGTRAP` signal, pausing execution in a debugger, whenever the asynchronous operation produces an error.
    ///
    /// - Returns: An asynchronous unit of work with the breakpoint-on-error condition applied.
    @_transparent @_alwaysEmitIntoClient @inlinable public func breakpointOnError() -> some AsynchronousUnitOfWork<Success> {
        breakpoint(receiveError: { _ in true })
    }
}
