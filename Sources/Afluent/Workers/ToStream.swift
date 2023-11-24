//
//  ToStream.swift
//
//
//  Created by Tyler Thompson on 11/11/23.
//

import Foundation

extension AsynchronousUnitOfWork {
    /// Converts the asynchronous unit of work into an `AsyncThrowingStream`.
    ///
    /// This method allows you to transform the result of an `AsynchronousUnitOfWork` into a stream, encapsulated in an `AsyncThrowingStream`. This can be useful when you want to bridge the single-value asynchronous operation into a stream-based API, or when you need to integrate with APIs expecting a stream of values.
    ///
    /// The resulting stream will emit a single value if the operation succeeds, or it will finish with an error if the operation fails.
    ///
    /// - Returns: An `AsyncThrowingStream` that represents the operation of the `AsynchronousUnitOfWork`. The stream emits a single value and then finishes, or finishes with an error if the operation fails.
    public func toStream() -> AsyncThrowingStream<Success, Error> {
        .init { continuation in
            Task {
                do {
                    let val = try await operation()
                    continuation.yield(val)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
