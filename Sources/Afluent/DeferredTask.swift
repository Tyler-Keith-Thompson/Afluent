//
//  DeferredTask.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation
@_exported import AsyncAlgorithms

/// A structure representing a deferred asynchronous unit of work.
///
/// `DeferredTask` conforms to the `AsynchronousUnitOfWork` protocol and allows you to encapsulate an asynchronous operation
/// that produces a result of type `Success`. The operation will be executed in a deferred manner, i.e., it won't start
/// until explicitly awaited.
///
/// - Note: The `Success` type must conform to the `Sendable` protocol.
public struct DeferredTask<Success: Sendable>: AsynchronousUnitOfWork {
    public let state: TaskState<Success>

    /// Initializes a new instance of `DeferredTask`.
    ///
    /// - Parameters:
    ///   - operation: The asynchronous operation that this task will execute. The operation should be a throwing, async closure that returns a value of type `Success`.
    public init(@_inheritActorContext @_implicitSelfCapture operation: @escaping @Sendable () async throws -> Success) {
        state = TaskState(operation: operation)
    }
}
