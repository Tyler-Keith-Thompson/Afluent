////
////  Materialize.swift
////
////
////  Created by Tyler Thompson on 11/3/23.
////
//
//import Foundation
//
//extension Workers {
//    struct Materialize<Upstream: AsynchronousUnitOfWork>: AsynchronousUnitOfWork {
//        typealias Success = Result<Upstream.Success, Error>
//
//        let state = TaskState<Success>()
//        let upstream: Upstream
//
//        init(upstream: Upstream) {
//            self.upstream = upstream
//        }
//
//        func _operation() async throws -> AsynchronousOperation<Success> {
//            AsynchronousOperation {
//                do {
//                    return try .success(await upstream.operation())
//                } catch {
//                    guard !(error is CancellationError) else { throw error }
//                    return .failure(error)
//                }
//            }
//        }
//    }
//}
//
//extension AsynchronousUnitOfWork {
//    /// Transforms the success or failure of the current `AsynchronousUnitOfWork` into a single `Result` value.
//    ///
//    /// This allows you to handle both success and error cases as regular emissions.
//    ///
//    /// Example:
//    /// ```swift
//    /// let task = DeferredTask { ... }
//    /// let materializedTask = task.materialize()
//    /// let result = try await materializedTask.execute()
//    /// switch result {
//    /// case .success(let value):
//    ///     // Handle success
//    /// case .failure(let error):
//    ///     // Handle error
//    /// }
//    /// ```
//    ///
//    /// - Returns: An `AsynchronousUnitOfWork` that emits a single `Result` value.
//    public func materialize() -> some AsynchronousUnitOfWork<Result<Success, Error>> {
//        Workers.Materialize(upstream: self)
//    }
//}
