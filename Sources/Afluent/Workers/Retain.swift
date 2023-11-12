//
//  Retain.swift
//
//
//  Created by Tyler Thompson on 10/30/23.
//

import Foundation

extension Workers {
    actor Retain<Upstream: AsynchronousUnitOfWork, Success>: AsynchronousUnitOfWork where Success == Upstream.Success {
        let state = TaskState<Success>()
        let upstream: Upstream
        var cachedSuccess: Success?
        
        init(upstream: Upstream) {
            self.upstream = upstream
        }
        
        func _operation() async throws -> Success {
            if let success = cachedSuccess {
                return success
            } else {
                let result = try await upstream.operation()
                return cache(result)
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
