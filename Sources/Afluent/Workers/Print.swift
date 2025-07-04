//
//  Print.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Foundation

extension AsynchronousUnitOfWork {
    /// Prints all events from this unit of work to the console, including operation start, output, error, and cancellation events.
    ///
    /// Use this operator for debugging or observing the lifecycle and values of an asynchronous unit of work. Output is sent to the standard output (console).
    ///
    /// ## Example
    /// ```
    /// try await DeferredTask { 42 }
    ///     .print("[Example]")
    ///     .execute()
    /// // Console output:
    /// // [Example] received operation
    /// // [Example] received output: 42
    /// ```
    ///
    /// - Parameter prefix: A string to prefix each log message with. Default is an empty string.
    /// - Returns: An `AsynchronousUnitOfWork` that forwards all events and logs them to the console.
    /// - Note: This operator is intended for debugging and observation purposes only.
    public func print(_ prefix: String = "") -> some AsynchronousUnitOfWork<Success> {
        handleEvents {
            Swift.print("\(prefix) received operation")
        } receiveOutput: {
            Swift.print("\(prefix) received output: \($0)")
        } receiveError: {
            Swift.print("\(prefix) received error: \($0)")
        } receiveCancel: {
            Swift.print("\(prefix) received cancellation")
        }
    }
}
