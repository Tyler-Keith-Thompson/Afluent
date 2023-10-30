//
//  Retain.swift
//
//
//  Created by Tyler Thompson on 10/30/23.
//

import Foundation

extension Workers {
    actor Retain<Success>: AsynchronousUnitOfWork {
        let state: TaskState<Success>
        var cachedSuccess: Success?
        init<U: AsynchronousUnitOfWork>(upstream: U) where Success == U.Success {
            state = TaskState.unsafeCreation()
            state.setOperation { [self] in
                if let success = await cachedSuccess {
                    return success
                } else {
                    let result = try await upstream.operation()
                    return await cache(result)
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
    /// Retains a successful result of the current unit of work, will not execute the operation again, even if retried.
    public func retain() -> some AsynchronousUnitOfWork<Success> {
        Workers.Retain(upstream: self)
    }
}
