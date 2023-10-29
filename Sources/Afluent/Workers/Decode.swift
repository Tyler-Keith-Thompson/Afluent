//
//  Decode.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Foundation

public protocol TopLevelDecoder<Input> {
    associatedtype Input
    func decode<T: Decodable>(_ type: T.Type, from: Self.Input ) throws -> T
}

extension JSONDecoder: TopLevelDecoder { }

extension Workers {
    struct Decode<Success: Sendable & Decodable>: AsynchronousUnitOfWork {
        let state: TaskState<Success>

        init<U: AsynchronousUnitOfWork, D: TopLevelDecoder>(upstream: U, decoder: D) where U.Success == D.Input {
            state = TaskState {
                try decoder.decode(Success.self, from: try await upstream.operation())
            }
        }
    }
}

extension AsynchronousUnitOfWork {
    /// Decodes the output from the upstream `AsynchronousUnitOfWork` using the specified top-level decoder.
    ///
    /// - Parameters:
    ///   - type: The type `T` to decode into, conforming to the `Decodable` protocol.
    ///   - decoder: The top-level decoder `D` used for decoding the upstream data.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` whose output is the decoded `T` type object.
    ///
    /// - Note: The generic constraint `Success == D.Input` ensures that the upstream unit of work emits a compatible type for the decoder.
    public func decode<T: Decodable, D: TopLevelDecoder>(type: T.Type, decoder: D) -> some AsynchronousUnitOfWork<T> where Success == D.Input {
        Workers.Decode(upstream: self, decoder: decoder)
    }
}
