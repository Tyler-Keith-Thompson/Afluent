//
//  Lazy.swift
//
//
//  Created by Tyler Thompson on 10/30/23.
//

import Foundation

extension Workers {
    actor Lazy<Success>: AsynchronousUnitOfWork {
        let state: TaskState<Success>
        var cachedResult: Result<Success, Error>?
        init<U: AsynchronousUnitOfWork>(upstream: U) where Success == U.Success {
            state = TaskState.unsafeCreation()
            state.setOperation { [self] in
                if let result = await cachedResult {
                    return try result.get()
                } else {
                    return try await cache(upstream.result).get()
                }
            }
        }
        
        func cache(_ result: Result<Success, Error>) -> Result<Success, Error> {
            cachedResult = result
            return result
        }
    }
}

extension AsynchronousUnitOfWork {
    /// Only runs the operation once, even when retried, caches the result (including error)
    public func `lazy`() -> some AsynchronousUnitOfWork<Success> {
        Workers.Lazy(upstream: self)
    }
}
