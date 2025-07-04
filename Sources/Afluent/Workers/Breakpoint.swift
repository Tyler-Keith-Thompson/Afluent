//
//  Breakpoint.swift
//
//
//  Created by Tyler Thompson on 11/1/23.
//

import Foundation

extension AsynchronousUnitOfWork {
    /// Inserts conditional breakpoints into the asynchronous unit of work,
    /// allowing you to pause execution when specific output values or errors occur.
    ///
    /// ## Discussion
    /// When the provided conditions evaluate to `true`, a `SIGTRAP` signal is raised,
    /// which typically causes the program to pause execution in a debugger.
    /// This enables you to inspect state or step through code at critical points.
    ///
    /// - Parameters:
    ///   - receiveOutput: A closure that asynchronously receives successful output values.
    ///     If this closure returns `true`, a breakpoint is triggered.
    ///     If `nil`, no breakpoint is triggered based on output values.
    ///   - receiveError: A closure that asynchronously receives errors produced by the operation.
    ///     If this closure returns `true`, a breakpoint is triggered.
    ///     If `nil`, no breakpoint is triggered based on errors.
    ///
    /// ## Example
    /// ```swift
    /// let task = DeferredTask<Int, Error> {
    ///     42
    /// }
    ///
    /// // Breakpoint when the output value is exactly 42
    /// let breakpointedTask = task.breakpoint(receiveOutput: { output in
    ///     return output == 42
    /// })
    ///
    /// try await breakpointedTask.value
    /// ```
    ///
    /// ```swift
    /// let failingTask = DeferredTask<Int, Error> {
    ///     throw NSError(domain: "Example", code: -1, userInfo: nil)
    /// }
    ///
    /// // Breakpoint when any error occurs
    /// let breakpointedTask = failingTask.breakpoint(receiveError: { error in
    ///     return true
    /// })
    ///
    /// try await breakpointedTask.value
    /// ```
    @_transparent @_alwaysEmitIntoClient @inlinable public func breakpoint(
        receiveOutput: (@Sendable (Success) async throws -> Bool)? = nil,
        receiveError: (@Sendable (Error) async throws -> Bool)? = nil
    ) -> some AsynchronousUnitOfWork<Success> {
        handleEvents(
            receiveOutput: { output in
                if try await receiveOutput?(output) == true {
                    raise(SIGTRAP)
                }
            },
            receiveError: { error in
                if try await receiveError?(error) == true {
                    raise(SIGTRAP)
                }
            })
    }

    /// Inserts an unconditional breakpoint on error into the asynchronous unit of work.
    ///
    /// ## Discussion
    /// This function triggers a `SIGTRAP` signal whenever the asynchronous operation produces an error,
    /// allowing you to pause execution immediately when any failure occurs.
    ///
    /// ## Example
    /// ```swift
    /// let failingTask = DeferredTask<Int, Error> {
    ///     throw NSError(domain: "Example", code: -1, userInfo: nil)
    /// }
    ///
    /// // Breakpoint on any error
    /// let breakpointedTask = failingTask.breakpointOnError()
    ///
    /// try await breakpointedTask.value
    /// ```
    @_transparent @_alwaysEmitIntoClient @inlinable public func breakpointOnError()
        -> some AsynchronousUnitOfWork<Success>
    {
        breakpoint(receiveError: { _ in true })
    }
}

