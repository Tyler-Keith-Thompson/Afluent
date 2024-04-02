//
//  UnwrapOrThrow.swift
//
//
//  Created by Tyler Thompson on 11/2/23.
//

import Foundation

extension AsynchronousUnitOfWork {
    /// Unwraps the optional value if present, or throws an error.
    public func unwrap<T>(orThrow error: @escaping @Sendable @autoclosure () -> Error) -> some AsynchronousUnitOfWork<T> where Success == T? {
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
