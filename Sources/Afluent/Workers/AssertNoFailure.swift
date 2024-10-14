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
    /// Adds a behavior to the unit of work that asserts no failures are emitted.
    ///
    /// This is often useful for debugging or in scenarios where you are certain
    /// that the upstream `AsynchronousUnitOfWork` should not emit any errors.
    ///
    /// - Returns: A new `AsynchronousUnitOfWork` that will assert if any failures are emitted from the upstream unit of work.
    public func assertNoFailure() -> some AsynchronousUnitOfWork<Success> {
        Workers.AssertNoFailure(upstream: self)
    }
}
