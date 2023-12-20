//
//  BreakpointSequence.swift
//
//
//  Created by Tyler Thompson on 12/10/23.
//

import Foundation

extension AsyncSequence {
    /// Introduces a breakpoint into the async sequence.
    ///
    /// This function allows you to introduce conditional breakpoints based on the output or error of the async sequence.
    /// If the provided conditions are met, a `SIGTRAP` signal is raised, pausing execution in a debugger.
    ///
    /// - Parameters:
    ///   - receiveOutput: A closure that takes the successful output of the sequence. If this closure returns `true`, a breakpoint is triggered. Default is `nil`.
    ///   - receiveError: A closure that takes any error produced by the sequence. If this closure returns `true`, a breakpoint is triggered. Default is `nil`.
    ///
    /// - Returns: An asynchronous unit of work with the breakpoint conditions applied.
    @_transparent @_alwaysEmitIntoClient @inlinable public func breakpoint(receiveOutput: ((Element) async throws -> Bool)? = nil, receiveError: ((Error) async throws -> Bool)? = nil) -> AsyncSequences.HandleEvents<Self> {
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

    /// Introduces a breakpoint into the async sequence when an error occurs.
    ///
    /// This function triggers a `SIGTRAP` signal, pausing execution in a debugger, whenever the async sequence produces an error.
    ///
    /// - Returns: An `AsyncSequence` with the breakpoint-on-error condition applied.
    @_transparent @_alwaysEmitIntoClient @inlinable public func breakpointOnError() -> AsyncSequences.HandleEvents<Self> {
        breakpoint(receiveError: { _ in true })
    }
}
