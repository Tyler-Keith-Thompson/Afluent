//
//  DeferredTask.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation

/// A deferred unit of asynchronous work that produces a result of type `Success`.
///
/// `DeferredTask` represents an asynchronous operation that is defined but does not start executing until it is explicitly started.
/// This allows precise control over when the asynchronous work begins, supporting scenarios where you want to set up an async operation ahead of time and
/// trigger its execution at a chosen moment.
///
/// This type conforms to the `AsynchronousUnitOfWork` protocol and is useful for wrapping async computations, network requests, or any other asynchronous operation
/// that may throw an error and returns a value.
///
/// ## Example
///
/// Basic usage with `execute()` to start and await the operation:
/// ```
/// let deferred = DeferredTask<Int> {
///     try await Task.sleep(nanoseconds: 1_000_000_000)
///     return 42
/// }
/// let result = try await deferred.execute()
/// print("Result is \(result)")
/// ```
///
/// Accessing the result via the `result` property (an async property that awaits completion):
/// ```
/// let deferred = DeferredTask<Int> {
///     10 * 5
/// }
/// let value = await deferred.result
/// print("Value is \(value)")
/// ```
///
/// Running the operation without awaiting its result immediately, via `run()`:
/// ```
/// let deferred = DeferredTask<Int> {
///     7 + 3
/// }
/// deferred.run()
/// // Later, you may await the result property or handle completion otherwise
/// ```
///
/// Subscribing to the task's events using `subscribe()`:
/// ```
/// let deferred = DeferredTask<String> {
///     "Hello, World!"
/// }
/// let cancellable = deferred.subscribe { event in
///     switch event {
///     case .success(let value):
///         print("Completed with value: \(value)")
///     case .failure(let error):
///         print("Failed with error: \(error)")
///     }
/// }
/// ```
///
/// Storing the subscription in a collection for lifecycle management:
/// ```
/// var cancellables = Set<AnyCancellable>()
/// let deferred = DeferredTask<Void> {
///     print("Task executed")
/// }
/// deferred.subscribe().store(in: &cancellables)
/// ```
///
/// Chaining with operators:
/// ```
/// let result = try await DeferredTask { 21 }
///     .map { $0 * 2 }
///     .execute() // result is 42
/// ```
public actor DeferredTask<Success: Sendable>: AsynchronousUnitOfWork {
    /// The internal state of the task, tracking its lifecycle and result.
    public let state = TaskState<Success>()
    
    /// The asynchronous operation to be executed when awaited.
    let operation: @Sendable () async throws -> Success

    /// Initializes a new `DeferredTask` with the provided asynchronous operation.
    ///
    /// - Parameter operation: An async closure representing the work to be performed. The closure can throw errors and must return a value of type `Success`.
    public init(
        @_inheritActorContext @_implicitSelfCapture operation: @Sendable @escaping () async throws
            -> Success
    ) {
        self.operation = operation
    }

    /// Executes the deferred asynchronous operation, returning an `AsynchronousOperation` that can be awaited.
    ///
    /// - Throws: Errors thrown by the underlying operation or a `CancellationError` if the task is no longer available.
    /// - Returns: An `AsynchronousOperation` wrapping the result of type `Success`.
    public func _operation() async throws -> AsynchronousOperation<Success> {
        AsynchronousOperation { [weak self] in
            guard let self else { throw CancellationError() }
            return try await self.operation()
        }
    }
}

