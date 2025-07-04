//
//  DiscardOutput.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Foundation

extension AsynchronousUnitOfWork {
    /// Discards the output values from the upstream `AsynchronousUnitOfWork`.
    ///
    /// Use this method when you are interested in the completion of the asynchronous operation
    /// but do not need the actual output values.
    ///
    /// Example:
    /// ```swift
    /// let originalWork: some AsynchronousUnitOfWork<Int> = ...
    /// let voidWork = originalWork.discardOutput()
    /// voidWork.start { result in
    ///     switch result {
    ///     case .success():
    ///         print("Completed successfully without output")
    ///     case .failure(let error):
    ///         print("Failed with error: \(error)")
    ///     }
    /// }
    /// ```
    ///
    /// - Returns: An `AsynchronousUnitOfWork` of type `Void` that emits a completion event when the upstream completes.
    public func discardOutput() -> some AsynchronousUnitOfWork<Void> {
        map { _ in }
    }
}

