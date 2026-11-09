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
    /// The queued jobs, in order. Each runs to completion before the next starts.
    private let jobs: AsyncStream<@Sendable () async -> Void>.Continuation
    /// The task that runs the queued jobs one at a time, inline. Cancelling it is how ``cancelAll()`` stops the
    /// queue: the running job sees the cancellation, and the jobs after it don't start.
    private let consumer: AnyCancellable

    public init() {
        let (stream, continuation) = AsyncStream<@Sendable () async -> Void>.makeStream()
        jobs = continuation
        consumer = DeferredTask {
            for await job in stream {
                await job()
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
        jobs.yield {
            guard !Task.isCancelled else { return }
            try? await task()
        }
    }

    /// Queues a task to be executed serially.
    ///
    /// If no task is currently running, the provided task is executed immediately.
    /// If a task is running, the provided task is added to the queue and will be executed once the current task completes.
    ///
    /// - Parameter task: The asynchronous task to be queued and executed.
    /// - Returns: The result of the task.
    /// - Throws: An error if the task throws an error, or `CancellationError` if the queue was cancelled before the
    ///   task started.
    public func enqueue<T: Sendable>(_ task: @Sendable @escaping () async throws -> T) async throws
        -> T
    {
        return try await withUnsafeThrowingContinuation { [weak self] continuation in
            guard let self else {
                continuation.resume(throwing: CancellationError())
                return
            }
            // The job runs inline in the queue's consumer task, and every path resumes the continuation once.
            self.jobs.yield {
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                do {
                    continuation.resume(returning: try await task())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
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
