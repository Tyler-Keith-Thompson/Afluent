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
/// This actor manages a queue of tasks, ensuring that only one task is executed at a time. If a task is currently running, any new tasks are added to the queue and executed sequentially.
///
/// ## Discussion
///
/// The `SerialTaskQueue` actor provides a way to manage task execution in a serial manner. When a new task is queued, it checks if another task is currently running. If no task is running, the new task is executed immediately. If a task is already running, the new task is added to a queue and will be executed once the current task completes.
/// This actor is useful in scenarios where tasks must be executed in a specific order or when you need to ensure that only one task is executed at a time to avoid race conditions.
public final class SerialTaskQueue: @unchecked Sendable {
    private var subscribers = Set<AnyCancellable>()
    private let (stream, deferredTaskContinuation) = AsyncStream<AnyAsynchronousUnitOfWork<Void>>.makeStream()

    public init() {
        DeferredTask {
            for await task in stream {
                try await task.execute()
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
    public func queue<T: Sendable>(_ task: @Sendable @escaping () async throws -> T) async throws -> T {
        return try await withUnsafeThrowingContinuation { [weak self] continuation in
            guard let self else { continuation.resume(throwing: CancellationError()); return }
            self.deferredTaskContinuation.yield(
                DeferredTask {
                    try continuation.resume(returning: await task())
                }.handleEvents(receiveCancel: {
                    continuation.resume(throwing: CancellationError())
                })
                .eraseToAnyUnitOfWork()
            )
        }
    }

    /// Cancels all the ongoing tasks in the queue
    public func cancelAll() {
        subscribers.removeAll()
    }
}
