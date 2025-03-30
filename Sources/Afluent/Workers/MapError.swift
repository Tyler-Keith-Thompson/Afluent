////
////  MapError.swift
////
////
////  Created by Tyler Thompson on 11/2/23.
////
//
//import Foundation
//
//extension Workers {
//    actor MapError<Upstream: AsynchronousUnitOfWork, Success: Sendable>: AsynchronousUnitOfWork
//    where Success == Upstream.Success {
//        let state = TaskState<Success>()
//        let upstream: Upstream
//        let transform: @Sendable (Error) -> Error
//
//        init(upstream: Upstream, transform: @Sendable @escaping (Error) -> Error) {
//            self.upstream = upstream
//            self.transform = transform
//        }
//
//        func _operation() async throws -> AsynchronousOperation<Success> {
//            AsynchronousOperation { [weak self] in
//                guard let self else { throw CancellationError() }
//
//                do {
//                    return try await self.upstream.operation()
//                } catch {
//                    guard !(error is CancellationError) else { throw error }
//
//                    throw self.transform(error)
//                }
//            }
//        }
//    }
//}
//
//extension AsynchronousUnitOfWork {
//    /// Transforms the error produced by the asynchronous unit of work.
//    ///
//    /// This function allows you to modify or replace the error produced by the current unit of work. It's useful for converting between error types or adding additional context to errors.
//    ///
//    /// - Parameter transform: A closure that takes the original error and returns a transformed error.
//    ///
//    /// - Returns: An asynchronous unit of work that produces the transformed error.
//    public func mapError(_ transform: @Sendable @escaping (Error) -> Error)
//        -> some AsynchronousUnitOfWork<Success>
//    {
//        Workers.MapError(upstream: self, transform: transform)
//    }
//
//    /// Transforms a specific error produced by the asynchronous unit of work.
//    ///
//    /// This function allows you to modify or replace a specific error produced by the current unit of work. If the error produced matches the provided error, the transform closure is applied; otherwise, the original error is propagated unchanged.
//    ///
//    /// - Parameters:
//    ///   - error: The specific error to be transformed. This error is equatable, allowing for precise matching.
//    ///   - transform: A closure that takes the matched error and returns a transformed error.
//    ///
//    /// - Returns: An asynchronous unit of work that produces either the transformed error (if a match was found) or the original error.
//    public func mapError<E: Error & Equatable>(
//        _ error: E, _ transform: @Sendable @escaping (Error) -> Error
//    ) -> some AsynchronousUnitOfWork<Success> {
//        mapError {
//            if let e = $0 as? E, e == error { return transform(e) }
//            return $0
//        }
//    }
//}
