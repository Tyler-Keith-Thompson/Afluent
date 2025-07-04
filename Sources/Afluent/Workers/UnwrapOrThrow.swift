//
//  UnwrapOrThrow.swift
//
//
//  Created by Tyler Thompson on 11/2/23.
//

import Foundation

extension AsynchronousUnitOfWork {
    /// Unwraps the optional value from this unit of work, or throws the given error if it is nil.
    ///
    /// Use this operator to convert an optional result into a non-optional one, failing the operation with your custom error if no value is present.
    ///
    /// ## Example
    /// ```
    /// enum MyError: Error { case missing }
    /// let result = try await DeferredTask { Int?.none }
    ///     .unwrap(orThrow: MyError.missing)
    ///     .execute() // throws MyError.missing if the task returns nil
    /// ```
    ///
    /// - Parameter error: The error to throw if the value is nil.
    /// - Returns: An `AsynchronousUnitOfWork` emitting the unwrapped value, or failing with the given error if nil.
    public func unwrap<T>(orThrow error: @Sendable @escaping @autoclosure () -> Error)
        -> some AsynchronousUnitOfWork<T> where Success == T?
    {
        tryMap { output in
            switch output {
                case .some(let value):
                    return value
                case nil:
                    throw error()
            }
        }
    }
}
