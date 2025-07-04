//
//  SerialTaskQueue.swift
//
//
//  Created by Tyler Thompson on 6/30/24.
//

import Atomics
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
/// async let first = queue.queue {
///     try await Task.sleep(nanoseconds: 2_000_000_000)
///     return "first"
/// }
/// async let second = queue.queue {
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
public final class SerialTaskQueue: @unchecked Sendable {
    private var subscribers = Set<AnyCancellable>()
    private let (stream, deferredTaskContinuation) = AsyncStream<AnyAsynchronousUnitOfWork<Void>>
        .makeStream()

    public init() {
        DeferredTask {
            for await task in stream {
                try? await task.execute()
            }
        }
        .subscribe()
        .store(in: &subscribers)
    }

    /// Queues a task to be executed serially.
    ///
    /// If no task is currently running, the provided task is executed immediately.
    /// If a task is running, the provided task is added to the queue and will be executed once the current task completes.
    ///
    /// - Parameter task: The asynchronous task to be queued and executed.
    /// - Returns: The result of the task.
    /// - Throws: An error if the task throws an error.
    public func queue<T: Sendable>(_ task: @Sendable @escaping () async throws -> T) async throws
        -> T
    {
        return try await withUnsafeThrowingContinuation { [weak self] continuation in
            guard let self else {
                continuation.resume(throwing: CancellationError())
                return
            }
            self.deferredTaskContinuation.yield(
                DeferredTask {
                    try continuation.resume(returning: await task())
                }.handleEvents(
                    receiveError: { error in
                        continuation.resume(throwing: error)
                    },
                    receiveCancel: {
                        continuation.resume(throwing: CancellationError())
                    }
                )
                .eraseToAnyUnitOfWork()
            )
        }
    }

    /// Cancels all the ongoing tasks in the queue.
    public func cancelAll() {
        subscribers.removeAll()
    }
}
