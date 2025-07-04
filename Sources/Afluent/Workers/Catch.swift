//
//  Catch.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation

extension Workers {
    struct Catch<
        Upstream: AsynchronousUnitOfWork, Downstream: AsynchronousUnitOfWork, Success: Sendable
    >: AsynchronousUnitOfWork
    where Success == Upstream.Success, Upstream.Success == Downstream.Success {
        let state = TaskState<Success>()
        let upstream: Upstream
        let handler: @Sendable (Error) async throws -> Downstream

        init(
            upstream: Upstream,
            @_inheritActorContext @_implicitSelfCapture _ handler: @Sendable @escaping (Error)
                async throws -> Downstream
        ) {
            self.upstream = upstream
            self.handler = handler
        }

        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation {
                do {
                    return try await upstream.operation()
                } catch {
                    guard !(error is CancellationError) else { throw error }

                    return try await handler(error).operation()
                }
            }
        }
    }
}

extension AsynchronousUnitOfWork {
    /// Returns an asynchronous unit of work that catches any errors emitted by the upstream asynchronous unit of work
    /// and recovers by replacing the failure with a new unit of work produced by the given non-throwing handler.
    ///
    /// The provided handler receives the caught error and must return a new asynchronous unit of work that produces the same success type.
    ///
    /// This operator is useful for implementing fallback or recovery logic when any error occurs.
    ///
    /// - Parameters:
    ///   - handler: A closure that takes the caught `Error` and returns an `AsynchronousUnitOfWork` to recover with.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that will catch any error from the upstream and replace it by the unit of work returned by the handler.
    ///
    /// ## Example
    /// ```swift
    /// struct FallbackError: Error {}
    ///
    /// let primaryTask = DeferredTask<Int> {
    ///     throw FallbackError()
    /// }
    ///
    /// let fallbackTask = DeferredTask<Int> {
    ///     return 42
    /// }
    ///
    /// let recoveredTask = primaryTask.catch { error in
    ///     print("Caught error: \(error), recovering with fallback")
    ///     return fallbackTask
    /// }
    ///
    /// let result = try await recoveredTask.operation().value
    /// // result == 42
    /// ```
    public func `catch`<D: AsynchronousUnitOfWork>(
        @_inheritActorContext @_implicitSelfCapture _ handler: @Sendable @escaping (Error) async ->
            D
    ) -> some AsynchronousUnitOfWork<D.Success> where Success == D.Success {
        Workers.Catch(upstream: self, handler)
    }

    /// Returns an asynchronous unit of work that catches a specific equatable error emitted by the upstream asynchronous unit of work
    /// and recovers by replacing the failure with a new unit of work produced by the given non-throwing handler.
    ///
    /// The handler is invoked only if the caught error matches the specified error value, otherwise the error is rethrown.
    ///
    /// Use this operator to selectively recover from specific error cases.
    ///
    /// - Parameters:
    ///   - error: The specific error value to catch.
    ///   - handler: A closure that takes the caught error of type `E` and returns an `AsynchronousUnitOfWork` to recover with.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that will catch and replace the specified error with the returned unit of work.
    ///
    /// ## Example
    /// ```swift
    /// enum NetworkError: Error, Equatable {
    ///     case timeout
    ///     case unreachable
    /// }
    ///
    /// let networkRequest = DeferredTask<Data> {
    ///     throw NetworkError.timeout
    /// }
    ///
    /// let fallbackRequest = DeferredTask<Data> {
    ///     return Data()
    /// }
    ///
    /// let recoveredRequest = networkRequest.catch(NetworkError.timeout) { error in
    ///     print("Caught timeout error, retrying with fallback")
    ///     return fallbackRequest
    /// }
    ///
    /// let data = try await recoveredRequest.operation().value
    /// ```
    public func `catch`<D: AsynchronousUnitOfWork, E: Error & Equatable>(
        _ error: E,
        @_inheritActorContext @_implicitSelfCapture _ handler: @Sendable @escaping (E) async -> D
    ) -> some AsynchronousUnitOfWork<D.Success> where Success == D.Success {
        tryCatch { err in
            guard let unwrappedError = (err as? E),
                unwrappedError == error
            else { throw err }
            return await handler(unwrappedError)
        }
    }

    /// Returns an asynchronous unit of work that tries to catch any errors emitted by the upstream asynchronous unit of work
    /// and recovers by replacing the failure with a new unit of work produced by the given throwing handler.
    ///
    /// The handler receives the caught error and can throw. If the handler throws, the error is rethrown.
    ///
    /// This operator is useful when recovery logic itself can throw asynchronously.
    ///
    /// - Parameters:
    ///   - handler: A closure that takes the caught `Error` and asynchronously throws or returns an `AsynchronousUnitOfWork` to recover with.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that tries to catch and replace any error with the unit of work returned by the handler.
    ///
    /// ## Example
    /// ```swift
    /// struct FallbackError: Error {}
    ///
    /// let primaryTask = DeferredTask<Int> {
    ///     throw FallbackError()
    /// }
    ///
    /// let fallbackTask = DeferredTask<Int> {
    ///     return 42
    /// }
    ///
    /// let recoveredTask = primaryTask.tryCatch { error in
    ///     print("Caught error: \(error), attempting recovery")
    ///     // Recovery could fail, so handler can throw
    ///     if Bool.random() {
    ///         return fallbackTask
    ///     } else {
    ///         throw error
    ///     }
    /// }
    ///
    /// let result = try await recoveredTask.operation().value
    /// ```
    public func tryCatch<D: AsynchronousUnitOfWork>(
        @_inheritActorContext @_implicitSelfCapture _ handler: @Sendable @escaping (Error)
            async throws -> D
    ) -> some AsynchronousUnitOfWork<D.Success> where Success == D.Success {
        Workers.Catch(upstream: self, handler)
    }

    /// Returns an asynchronous unit of work that tries to catch a specific equatable error emitted by the upstream asynchronous unit of work
    /// and recovers by replacing the failure with a new unit of work produced by the given throwing handler.
    ///
    /// The handler is invoked only if the caught error matches the specified error value. If the handler throws, the error is rethrown.
    ///
    /// Use this operator to selectively recover from specific error cases with potentially throwing recovery logic.
    ///
    /// - Parameters:
    ///   - error: The specific error value to catch.
    ///   - handler: A closure that takes the caught error of type `E`, asynchronously throws or returns an `AsynchronousUnitOfWork` to recover with.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that tries to catch and replace the specified error with the returned unit of work.
    ///
    /// ## Example
    /// ```swift
    /// enum NetworkError: Error, Equatable {
    ///     case timeout
    ///     case unreachable
    /// }
    ///
    /// let networkRequest = DeferredTask<Data> {
    ///     throw NetworkError.timeout
    /// }
    ///
    /// let fallbackRequest = DeferredTask<Data> {
    ///     return Data()
    /// }
    ///
    /// let recoveredRequest = networkRequest.tryCatch(NetworkError.timeout) { error in
    ///     print("Handling timeout error with potentially throwing recovery")
    ///     if Bool.random() {
    ///         return fallbackRequest
    ///     } else {
    ///         throw error
    ///     }
    /// }
    ///
    /// let data = try await recoveredRequest.operation().value
    /// ```
    public func tryCatch<D: AsynchronousUnitOfWork, E: Error & Equatable>(
        _ error: E,
        @_inheritActorContext @_implicitSelfCapture _ handler: @Sendable @escaping (E) async throws
            -> D
    ) -> some AsynchronousUnitOfWork<D.Success> where Success == D.Success {
        tryCatch { err in
            guard let unwrappedError = (err as? E),
                unwrappedError == error
            else { throw err }
            return try await handler(unwrappedError)
        }
    }
}
