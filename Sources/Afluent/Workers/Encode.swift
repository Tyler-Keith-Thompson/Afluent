//
//  Encode.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Foundation

public protocol TopLevelEncoder<Output> {
    associatedtype Output
    func encode<T: Encodable>(_ value: T) throws -> Output
}

extension JSONEncoder: TopLevelEncoder { }

extension Workers {
    struct Encode<Success: Sendable>: AsynchronousUnitOfWork {
        let state: TaskState<Success>

        init<U: AsynchronousUnitOfWork, E: TopLevelEncoder>(upstream: U, encoder: E) where Success == E.Output, U.Success: Encodable {
            state = TaskState {
                try encoder.encode(try await upstream.operation())
            }
        }
    }
}

extension AsynchronousUnitOfWork {
    /// Encodes the successful output values from the upstream `AsynchronousUnitOfWork` using the provided encoder.
    ///
    /// - Parameter encoder: The encoder to use for encoding the successful output values.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` emitting the encoded values as output of type `E.Output`.
    ///
    /// - Note: The returned `AsynchronousUnitOfWork` will fail if the encoding process fails.
    public func encode<E: TopLevelEncoder>(encoder: E) -> some AsynchronousUnitOfWork<E.Output> where Success: Encodable {
        Workers.Encode(upstream: self, encoder: encoder)
    }
}
