//
//  EraseToAnyAsynchronousUnitOfWork.swift
//
//
//  Created by Tyler Thompson on 10/30/23.
//

import Foundation

/// A unit of work that performs type erasure by wrapping another unit of work.
public struct AnyAsynchronousUnitOfWork<Success: Sendable>: AsynchronousUnitOfWork {
    let upstream: any AsynchronousUnitOfWork<Success>

    public init(_ upstream: any AsynchronousUnitOfWork<Success>) {
        self.upstream = upstream
    }

    // IMPORTANT:
    // this type must explicitly call the upstream's implementation of all AsynchronousUnitOfWork protocol properties
    // this is because we cannot assume any given worker will use the default implementation

    public var state: TaskState<Success> {
        upstream.state
    }
    public var result: Result<Success, Error> {
        get async throws {
            try await upstream.result
        }
    }
    public func run(priority: TaskPriority?) {
        upstream.run(priority: priority)
    }
    @discardableResult
    public func execute(priority: TaskPriority?) async throws -> Success {
        try await upstream.execute(priority: priority)
    }
    #if swift(>=6)
        @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
        public func run(
            executorPreference taskExecutor: (any TaskExecutor)?, priority: TaskPriority?
        ) {
            upstream.run(executorPreference: taskExecutor, priority: priority)
        }
        @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
        @discardableResult
        public func execute(
            executorPreference taskExecutor: (any TaskExecutor)?, priority: TaskPriority?
        ) async throws -> Success {
            try await upstream.execute(executorPreference: taskExecutor, priority: priority)
        }
    #endif
    @Sendable
    public func _operation() async throws -> AsynchronousOperation<Success> {
        try await upstream._operation()
    }
    public func cancel() {
        upstream.cancel()
    }
}

extension AsynchronousUnitOfWork {
    /// Type erases the current unit of work, useful when you need a concrete type
    public func eraseToAnyUnitOfWork() -> AnyAsynchronousUnitOfWork<Success> {
        AnyAsynchronousUnitOfWork(self)
    }
}
