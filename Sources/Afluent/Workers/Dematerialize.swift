////
////  Dematerialize.swift
////
////
////  Created by Tyler Thompson on 11/3/23.
////
//
//import Foundation
//
//extension AsynchronousUnitOfWork {
//    /// Transforms a `Result` value emitted by the current `AsynchronousUnitOfWork` into its underlying success or failure.
//    ///
//    /// This operator is the inverse of `materialize`. It expects the `AsynchronousUnitOfWork` to emit a `Result` value and will either
//    /// propagate the success value or throw the error contained within the `Result`.
//    ///
//    /// Example:
//    /// ```swift
//    /// let task = DeferredTask<Result<String, Error>> { ... }
//    /// let dematerializedTask = task.dematerialize()
//    /// do {
//    ///     let value: String = try await dematerializedTask.execute()
//    ///     // Handle success value
//    /// } catch {
//    ///     // Handle error
//    /// }
//    /// ```
//    ///
//    /// - Returns: An `AsynchronousUnitOfWork` that emits the success value or throws the error contained within the `Result`.
//    /// - Throws: The error contained within the `Result` if it's a failure.
//    public func dematerialize<T: Sendable>() -> some AsynchronousUnitOfWork<T>
//    where Success == Result<T, Error> {
//        tryMap { try $0.get() }
//    }
//}
