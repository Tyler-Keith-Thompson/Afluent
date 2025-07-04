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

extension JSONEncoder: TopLevelEncoder {}

extension Workers {
    struct Encode<Upstream: AsynchronousUnitOfWork, Encoder: TopLevelEncoder, Success: Sendable>:
        AsynchronousUnitOfWork
    where Success == Encoder.Output, Upstream.Success: Encodable {
        final class State: @unchecked Sendable {
            let lock = NSRecursiveLock()
            private let encoder: Encoder
            init(encoder: Encoder) {
                self.encoder = encoder
            }

            func encode<T: Encodable>(_ value: T) throws -> Encoder.Output {
                try lock.protect {
                    try encoder.encode(value)
                }
            }
        }

        let state = TaskState<Success>()
        let upstream: Upstream
        let encoderState: State

        init(upstream: Upstream, encoder: Encoder) {
            self.upstream = upstream
            encoderState = State(encoder: encoder)
        }

        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation {
                try encoderState.encode(await upstream.operation())
            }
        }
    }
}

extension AsynchronousUnitOfWork {
    /// Encodes the successful output value from the upstream `AsynchronousUnitOfWork` using the provided encoder.
    ///
    /// Use this operator when you want to transform an encodable output (such as a model or primitive value) into an encoded form (like Data) using a given encoder (e.g., JSONEncoder).
    ///
    /// ## Example
    /// ```swift
    /// struct Person: Encodable { let name: String }
    /// let work = DeferredTask { Person(name: "Alice") }
    /// let encoded: some AsynchronousUnitOfWork<Data> = work.encode(encoder: JSONEncoder())
    /// let data = try await encoded.execute()
    /// // 'data' now contains the encoded JSON representation of the Person
    /// ```
    ///
    /// - Parameter encoder: The encoder to use for encoding the successful output value.
    /// - Returns: An `AsynchronousUnitOfWork` emitting the encoded value as output of type `E.Output`.
    /// - Note: The returned unit of work will fail if the encoding process throws an error.
    public func encode<E: TopLevelEncoder>(encoder: E) -> some AsynchronousUnitOfWork<E.Output>
    where Success: Encodable, E.Output: Sendable {
        Workers.Encode(upstream: self, encoder: encoder)
    }
}
