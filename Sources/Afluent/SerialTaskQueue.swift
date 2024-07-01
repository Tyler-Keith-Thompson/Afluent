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
public final actor SerialTaskQueue<T: Sendable> {
    private var lock = NSRecursiveLock()
    private let isRunningTask = ManagedAtomic(false)
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
        defer {
            isRunningTask.store(false, ordering: .sequentiallyConsistent)
            popAndExecute()
        }
        if !isRunningTask.load(ordering: .sequentiallyConsistent) {
            isRunningTask.store(true, ordering: .sequentiallyConsistent)
            return try await task()
        } else {
            let sub = SingleValueSubject<T>()
            append(DeferredTask {
                isRunningTask.store(true, ordering: .sequentiallyConsistent)
                try sub.send(await task())
            })
            return try await sub.execute()
        }
    }

    private func append(_ task: DeferredTask<Void>) {
        lock.protect {
            tasks.append(task)
        }
    }

    private func popAndExecute() {
        let task = lock.protect { () -> DeferredTask<Void>? in
            guard !tasks.isEmpty else { return nil }
            return tasks.removeFirst()
        }
        task?.run()
    }
}
