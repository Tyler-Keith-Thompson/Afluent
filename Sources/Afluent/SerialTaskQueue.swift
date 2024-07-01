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
public final class SerialTaskQueue<T: Sendable>: @unchecked Sendable {
    private var lock = NSRecursiveLock()
    private var tasks = [DeferredTask<Void>]()

    public init() { }

    /// Queues a task to be executed serially.
    ///
    /// If no task is currently running, the provided task is executed immediately.
    /// If a task is running, the provided task is added to the queue and will be executed once the current task completes.
    ///
    /// - Parameter task: The asynchronous task to be queued and executed.
    /// - Returns: The result of the task.
    /// - Throws: An error if the task throws an error.
    public func queue(_ task: @Sendable @escaping () async throws -> T) async throws -> T {
        if lock.protect({ tasks.isEmpty }) {
            return try await task()
        }
        return try await withUnsafeThrowingContinuation { continuation in
            append(DeferredTask { [weak self] in
                guard let self else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                do {
                    try continuation.resume(returning: await task())
                } catch {
                    continuation.resume(throwing: error)
                }
                self.popAndExecute()
            })
        }
    }

    /// Cancels all the ongoing tasks in the queue
    public func cancelAll() {
        lock.protect { tasks }.forEach { $0.cancel() }
    }

    private func append(_ task: DeferredTask<Void>) {
        lock.protect {
            tasks.append(task)
        }
    }

    private func popAndExecute() {
        lock.protect { () -> DeferredTask<Void>? in
            guard !tasks.isEmpty else { return nil }
            return tasks.removeFirst()
        }?.run()
    }

    deinit {
        tasks.forEach { $0.cancel() }
    }
}
