//
//  SerialTaskQueue.swift
//
//
//  Created by Tyler Thompson on 6/30/24.
//

import Foundation

/// A serial task queue that ensures tasks are executed one at a time.
///
/// This class manages a queue of asynchronous tasks, executing each task sequentially to prevent concurrent execution.
/// It is useful when tasks must run in order or when you want to avoid race conditions by ensuring only one task runs at any given time.
///
/// ## Example
/// ```swift
/// let queue = SerialTaskQueue()
///
/// async let first = queue.enqueue {
///     try await Task.sleep(nanoseconds: 2_000_000_000)
///     return "first"
/// }
/// async let second = queue.enqueue {
///     try await Task.sleep(nanoseconds: 1_000_000_000)
///     return "second"
/// }
///
/// // The results are delivered in order: ["first", "second"], even though the second task sleeps less
/// let results = try await [first, second]
/// print(results)
///
/// // To cancel all tasks:
/// queue.cancelAll()
/// ```
public final class SerialTaskQueue: Sendable {
    private let deferredTaskContinuation: AsyncStream<AnyAsynchronousUnitOfWork<Void>>.Continuation
    /// The task that runs the queued work one at a time. Cancelling it is how ``cancelAll()`` stops the queue.
    private let consumer: AnyCancellable

    public init() {
        let (stream, continuation) = AsyncStream<AnyAsynchronousUnitOfWork<Void>>.makeStream()
        deferredTaskContinuation = continuation
        consumer = DeferredTask {
            for await task in stream {
                try? await task.execute()
            }
        }
        .subscribe()
    }

    /// Queues a task to be executed serially without waiting for completion (fire-and-forget).
    ///
    /// If no task is currently running, the provided task is executed immediately.
    /// If a task is running, the provided task is added to the queue and will be executed once the current task completes.
    /// This method returns immediately without waiting for the task to complete.
    /// Any errors thrown by the task are silently ignored.
    ///
    /// - Parameter task: The asynchronous throwing task to be queued and executed.
    public func enqueue(_ task: @Sendable @escaping () async throws -> Void) {
        deferredTaskContinuation.yield(
            DeferredTask {
                try await task()
            }
            .eraseToAnyUnitOfWork()
        )
    }

    /// Queues a task to be executed serially.
    ///
    /// If no task is currently running, the provided task is executed immediately.
    /// If a task is running, the provided task is added to the queue and will be executed once the current task completes.
    ///
    /// - Parameter task: The asynchronous task to be queued and executed.
    /// - Returns: The result of the task.
    /// - Throws: An error if the task throws an error.
    public func enqueue<T: Sendable>(_ task: @Sendable @escaping () async throws -> T) async throws
        -> T
    {
        return try await withUnsafeThrowingContinuation { [weak self] continuation in
            guard let self else {
                continuation.resume(throwing: CancellationError())
                return
            }
            // The job can finish and then be cancelled before its unit of work returns, which would reach
            // `receiveCancel` after the result was delivered. Only the first resume goes through.
            let resumed = ManagedCriticalState(false)
            @Sendable func resume(with result: Result<T, any Error>) {
                let isFirst = resumed.withCriticalRegion { resumed in
                    defer { resumed = true }
                    return !resumed
                }
                if isFirst { continuation.resume(with: result) }
            }
            self.deferredTaskContinuation.yield(
                DeferredTask {
                    resume(with: .success(try await task()))
                }.handleEvents(
                    receiveError: { error in
                        resume(with: .failure(error))
                    },
                    receiveCancel: {
                        resume(with: .failure(CancellationError()))
                    }
                )
                .eraseToAnyUnitOfWork()
            )
        }
    }

    /// Queues a task to be executed serially.
    ///
    /// If no task is currently running, the provided task is executed immediately.
    /// If a task is running, the provided task is added to the queue and will be executed once the current task completes.
    ///
    /// - Parameter task: The asynchronous task to be queued and executed.
    /// - Returns: The result of the task.
    /// - Throws: An error if the task throws an error.
    /// - Note: This method has been renamed to `enqueue`. Use `enqueue` instead.
    @available(*, deprecated, renamed: "enqueue", message: "Use enqueue instead")
    public func queue<T: Sendable>(_ task: @Sendable @escaping () async throws -> T) async throws
        -> T
    {
        return try await enqueue(task)
    }

    /// Cancels all the ongoing tasks in the queue.
    public func cancelAll() {
        consumer.cancel()
    }
}
