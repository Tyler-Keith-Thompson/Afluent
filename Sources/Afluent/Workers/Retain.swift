//
//  Retain.swift
//
//
//  Created by Tyler Thompson on 10/30/23.
//

import Foundation

extension Workers {
    actor Retain<Upstream: AsynchronousUnitOfWork, Success>: AsynchronousUnitOfWork
    where Success == Upstream.Success {
        let state = TaskState<Success>()
        let upstream: Upstream
        var cachedSuccess: Success?

        init(upstream: Upstream) {
            self.upstream = upstream
        }

        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation { [weak self] in
                guard let self else { throw CancellationError() }

                if let success = await self.cachedSuccess {
                    return success
                } else {
                    let result = try await self.upstream.operation()
                    return await self.cache(result)
                }
            }
        }

        func cache(_ result: Success) -> Success {
            cachedSuccess = result
            return result
        }
    }
}

extension AsynchronousUnitOfWork {
    /// Retains the successful result of this unit of work, ensuring the operation is performed only once. Subsequent executions return the cached result.
    ///
    /// Use this operator when you want to prevent repeated side effects or recomputation by caching the result of the first execution.
    ///
    /// ## Example
    /// ```
    /// var runCount = 0
    /// let task = DeferredTask { runCount += 1; return 42 }
    ///     .retain()
    ///
    /// let a = try await task.execute() // runCount is 1
    /// let b = try await task.execute() // runCount is still 1, value is cached
    /// ```
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that caches and reuses its initial successful result.
    /// - Note: If the operation fails, no value is cached and subsequent executions will retry the operation.
    public func retain() -> some AsynchronousUnitOfWork<Success> {
        Workers.Retain(upstream: self)
    }
}
