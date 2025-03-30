////
////  ReplaceError.swift
////
////
////  Created by Tyler Thompson on 10/28/23.
////
//
//import Foundation
//
//extension Workers {
//    struct ReplaceError<Upstream: AsynchronousUnitOfWork, Success: Sendable>: AsynchronousUnitOfWork
//    where Upstream.Success == Success {
//        let state = TaskState<Success>()
//        let upstream: Upstream
//        let newValue: Success
//
//        init(upstream: Upstream, newValue: Success) {
//            self.upstream = upstream
//            self.newValue = newValue
//        }
//
//        func _operation() async throws -> AsynchronousOperation<Success> {
//            AsynchronousOperation {
//                do {
//                    return try await upstream.operation()
//                } catch {
//                    guard !(error is CancellationError) else { throw error }
//                    return newValue
//                }
//            }
//        }
//    }
//}
//
//extension AsynchronousUnitOfWork {
//    /// Replaces any errors from the upstream `AsynchronousUnitOfWork` with the provided value.
//    ///
//    /// - Parameter value: The value to emit upon encountering an error.
//    ///
//    /// - Returns: An `AsynchronousUnitOfWork` that emits the specified value instead of failing when the upstream fails.
//    public func replaceError(with value: Success) -> some AsynchronousUnitOfWork<Success> {
//        Workers.ReplaceError(upstream: self, newValue: value)
//    }
//}
