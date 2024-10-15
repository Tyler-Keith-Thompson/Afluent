//
//  ToAsyncSequence.swift
//
//
//  Created by Tyler Thompson on 11/11/23.
//

import Foundation

/// A sequence that represents a single execution of an asynchronous unit of work.
///
/// `AsynchronousUnitOfWorkSequence` is an `AsyncSequence` that wraps an `AsynchronousUnitOfWork`. It provides a way to use asynchronous units of work in contexts where an `AsyncSequence` is expected. This sequence emits a single value and then completes.
///
/// - Note: The sequence will only execute the unit of work once. Subsequent iterations will receive `nil`, indicating the end of the sequence.
public struct AsynchronousUnitOfWorkSequence<UnitOfWork: AsynchronousUnitOfWork>: AsyncSequence,
    Sendable
{
    public typealias Element = UnitOfWork.Success
    let unitOfWork: UnitOfWork

    public struct AsyncIterator: AsyncIteratorProtocol, Sendable {
        let unitOfWork: UnitOfWork
        var executed = false

        public mutating func next() async throws -> UnitOfWork.Success? {
            if !executed {
                executed = true
                return try await unitOfWork.operation()
            } else {
                return nil
            }
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(unitOfWork: unitOfWork)
    }
}

extension AsynchronousUnitOfWork {
    /// Converts the asynchronous unit of work into an `AsyncThrowingStream`.
    ///
    /// - Deprecated: This stream was replaced with a custom `AsyncSequence` which behaves better.
    @available(
        *, deprecated, renamed: "toAsyncSequence()",
        message: "This stream was replaced with a custom AsyncSequence which behaves better"
    )
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

    /// Converts the asynchronous unit of work into an `AsyncSequence`.
    ///
    /// This method transforms the result of an `AsynchronousUnitOfWork` into an `AsyncSequence`. It's useful for integrating the single-value asynchronous operation into APIs that work with sequences, or for using async/await in a more sequential, iterative manner.
    ///
    /// The resulting sequence emits a single value if the operation succeeds, or throws an error if the operation fails. After emitting its single value or error, the sequence completes.
    ///
    /// - Returns: An `AsynchronousUnitOfWorkSequence` that represents the operation of the `AsynchronousUnitOfWork`.
    public func toAsyncSequence() -> AsynchronousUnitOfWorkSequence<Self> {
        AsynchronousUnitOfWorkSequence(unitOfWork: self)
    }
}
