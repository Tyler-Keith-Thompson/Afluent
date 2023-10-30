//
//  Catch.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation

extension Workers {
    struct Catch<Success: Sendable>: AsynchronousUnitOfWork {
        let state: TaskState<Success>

        init<U: AsynchronousUnitOfWork, D: AsynchronousUnitOfWork>(upstream: U, @_inheritActorContext @_implicitSelfCapture _ handler: @escaping @Sendable (Error) async throws -> D) where Success == U.Success, U.Success == D.Success {
            state = TaskState {
                do {
                    return try await upstream.operation()
                } catch {
                    if error is CancellationError {
                        throw error
                    } else {
                        return try await handler(error).operation()
                    }
                }
            }
        }
    }
}

extension AsynchronousUnitOfWork {
    /// Catches any errors emitted by the upstream `AsynchronousUnitOfWork` and handles them using the provided closure.
    ///
    /// - Parameters:
    ///   - handler: A closure that takes an `Error` and returns an `AsynchronousUnitOfWork`.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that will catch and handle any errors emitted by the upstream unit of work.
    public func `catch`<D: AsynchronousUnitOfWork>(@_inheritActorContext @_implicitSelfCapture _ handler: @escaping @Sendable (Error) async -> D) -> some AsynchronousUnitOfWork<D.Success> where Success == D.Success {
        Workers.Catch(upstream: self, handler)
    }
    
    /// Catches a specific type of error emitted by the upstream `AsynchronousUnitOfWork` and handles them using the provided closure.
    ///
    /// - Parameters:
    ///   - error: The specific error type to catch.
    ///   - handler: A closure that takes an `Error` and returns an `AsynchronousUnitOfWork`.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that will catch and handle the specific error.
    public func `catch`<D: AsynchronousUnitOfWork, E: Error & Equatable>(_ error: E, @_inheritActorContext @_implicitSelfCapture _ handler: @escaping @Sendable (E) async -> D) -> some AsynchronousUnitOfWork<D.Success> where Success == D.Success {
        tryCatch { err in
            guard let unwrappedError = (err as? E),
                  unwrappedError == error else { throw err }
            return await handler(unwrappedError)
        }
    }
    
    /// Tries to catch any errors emitted by the upstream `AsynchronousUnitOfWork` and handles them using the provided throwing closure.
    ///
    /// - Parameters:
    ///   - handler: A closure that takes an `Error` and returns an `AsynchronousUnitOfWork`, potentially throwing an error.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that will try to catch and handle any errors emitted by the upstream unit of work.
    public func tryCatch<D: AsynchronousUnitOfWork>(@_inheritActorContext @_implicitSelfCapture _ handler: @escaping @Sendable (Error) async throws -> D) -> some AsynchronousUnitOfWork<D.Success> where Success == D.Success {
        Workers.Catch(upstream: self, handler)
    }
    
    /// Tries to catch a specific type of error emitted by the upstream `AsynchronousUnitOfWork` and handles them using the provided throwing closure.
    ///
    /// - Parameters:
    ///   - error: The specific error type to catch.
    ///   - handler: A closure that takes an `Error` and returns an `AsynchronousUnitOfWork`, potentially throwing an error.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that will try to catch and handle the specific error.
    public func tryCatch<D: AsynchronousUnitOfWork, E: Error & Equatable>(_ error: E, @_inheritActorContext @_implicitSelfCapture _ handler: @escaping @Sendable (E) async throws -> D) -> some AsynchronousUnitOfWork<D.Success> where Success == D.Success {
        tryCatch { err in
            guard let unwrappedError = (err as? E),
                  unwrappedError == error else { throw err }
            return try await handler(unwrappedError)
        }
    }
}
