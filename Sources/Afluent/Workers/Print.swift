//
//  Print.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Foundation

extension AsynchronousUnitOfWork {
    /// Logs events from the upstream `AsynchronousUnitOfWork` to the console.
    ///
    /// - Parameters:
    ///   - prefix: A string to prefix each log message with. Default is an empty string.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that behaves identically to the upstream but logs events.
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
