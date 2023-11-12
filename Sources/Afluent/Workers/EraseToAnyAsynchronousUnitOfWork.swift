//
//  EraseToAnyAsynchronousUnitOfWork.swift
//
//
//  Created by Tyler Thompson on 10/30/23.
//

import Foundation

/// A unit of work that performs type erasure by wrapping another unit of work.
public struct AnyAsynchronousUnitOfWork<Success: Sendable>: AsynchronousUnitOfWork {
    public let state = TaskState<Success>()
    let upstream: any AsynchronousUnitOfWork<Success>

    public init(_ upstream: any AsynchronousUnitOfWork<Success>) {
        self.upstream = upstream
    }
    
    public func _operation() async throws -> AsynchronousOperation<Success> {
        try await upstream._operation()
    }
}

extension AsynchronousUnitOfWork {
    /// Type erases the current unit of work, useful when you need a concrete type
    public func eraseToAnyUnitOfWork() -> AnyAsynchronousUnitOfWork<Success> {
        AnyAsynchronousUnitOfWork(self)
    }
}
