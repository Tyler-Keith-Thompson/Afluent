//
//  AssertNoFailure.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation

extension Workers {
    struct AssertNoFailure<Upstream: AsynchronousUnitOfWork, Success: Sendable>:
        AsynchronousUnitOfWork
    where Upstream.Success == Success {
        let state = TaskState<Success>()
        let upstream: Upstream

        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation {
                do {
                    return try await upstream.operation()
                } catch {
                    if !(error is CancellationError) {
                        assertionFailure(
                            "Expected no error in asynchronous unit of work, but got: \(error)")
                    }
                    throw error
                }
            }
        }
    }
}

extension AsynchronousUnitOfWork {
    /// Returns a new unit of work that asserts if the upstream unit of work throws any error other than cancellation.
    ///
    /// This operator is useful for debugging or development when you expect the upstream
    /// `AsynchronousUnitOfWork` to never fail. If an unexpected error is thrown, an assertion failure
    /// will be triggered, helping you catch and diagnose issues early.
    ///
    /// ## Example
    /// ```swift
    /// // A unit of work that succeeds
    /// let successWork = DeferredTask {
    ///     return "Success"
    /// }
    ///
    /// // Wrapping with `assertNoFailure` should not cause assertion failures here
    /// let guaranteedSuccess = successWork.assertNoFailure()
    ///
    /// // Uncommenting the following would trigger an assertion failure if the task throws:
    /// // let failingWork = DeferredTask<String> {
    /// //     throw NSError(domain: "TestError", code: 1)
    /// // }
    /// // let assertedFailingWork = failingWork.assertNoFailure()
    /// ```
    ///
    /// - Returns: A new `AsynchronousUnitOfWork` that will assert if the upstream unit of work throws any non-cancellation error.
    public func assertNoFailure() -> some AsynchronousUnitOfWork<Success> {
        Workers.AssertNoFailure(upstream: self)
    }
}
