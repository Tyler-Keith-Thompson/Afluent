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
    /// A queued job: `run` does the work and resumes its awaiter, `cancel` resumes the awaiter with
    /// `CancellationError` when the job never starts. Exactly one of them is called.
    ///
    /// It is `@unchecked Sendable` because its closures capture the caller's `sending` task, which isn't `Sendable`,
    /// and one owner holds a job at a time: `enqueue` hands it to the state, and the consumer or `cancel` takes it
    /// out to call one of its closures.
    private struct Job: @unchecked Sendable {
        let run: () async -> Void
        let cancel: () -> Void
    }

    /// The jobs waiting to start, in order, and the consumer when it waits for one.
    ///
    /// Jobs leave it only by being moved out, never released in it: releasing a job's captures can run a `deinit`
    /// that calls back into the queue, which would take the lock again.
    private struct State {
        /// The queued jobs, from `head` on; the slots before `head` were taken and are empty.
        var pending: [Job?] = []
        var head = 0
        /// The consumer, suspended until a job is queued or the queue is cancelled.
        var waitingConsumer: UnsafeContinuation<Job?, Never>?
        var isCancelled = false

        /// Moves the next queued job out, if any.
        ///
        /// - Complexity: Amortized O(1): the empty prefix is dropped once it is half the array.
        mutating func takeNext() -> Job? {
            guard head < pending.count else { return nil }
            let job = pending[head].take()
            head += 1
            if head == pending.count {
                pending.removeAll(keepingCapacity: true)
                head = 0
            } else if head * 2 >= pending.count {
                pending.removeFirst(head)
                head = 0
            }
            return job
        }

        /// Marks the queue cancelled and moves out every job that hasn't started.
        mutating func cancel() -> [Job] {
            isCancelled = true
            var unstarted = [Job]()
            unstarted.reserveCapacity(pending.count - head)
            for index in head..<pending.count {
                if let job = pending[index].take() { unstarted.append(job) }
            }
            pending = []
            head = 0
            return unstarted
        }
    }

    private let state: CriticalState<State>
    /// The task that runs the queued jobs one at a time, each in a child task. Cancelling it cancels the running job.
    private let consumer: AnyCancellable

    public init() {
        let state = CriticalState(State())
        self.state = state
        consumer = DeferredTask {
            while let job = await Self.next(state) {
                // A child task: cancellation reaches the job from the queue, but a job that cancels its own task
                // can't cancel the queue. ``cancelAll()`` cancels this task before it returns, so a job taken just
                // before it is cancelled rather than started.
                async let finished: Void = Self.start(job)
                await finished
            }
        }
        .subscribe()
    }

    deinit {
        Self.cancel(state)
    }

    /// Runs `job`, or cancels it when the queue was cancelled after the consumer took it.
    private static func start(_ job: Job) async {
        if Task.isCancelled {
            job.cancel()
        } else {
            await job.run()
        }
    }

    /// Waits for the next job; `nil` once the queue is cancelled.
    private static func next(_ state: CriticalState<State>) async -> Job? {
        await withUnsafeContinuation { continuation in
            enum Next {
                case job(Job)
                case finished
                case wait
            }
            let next: Next = state.withCriticalRegion { state in
                if state.isCancelled { return .finished }
                if let job = state.takeNext() { return .job(job) }
                state.waitingConsumer = continuation
                return .wait
            }
            switch next {
                case .job(let job): continuation.resume(returning: job)
                case .finished: continuation.resume(returning: nil)
                case .wait: break
            }
        }
    }

    /// Queues `job`, or cancels it when the queue is already cancelled.
    private func add(_ job: Job) {
        enum Added {
            case queued
            case handedToConsumer(UnsafeContinuation<Job?, Never>, Job)
            case rejected(Job)
        }
        let added: Added = state.withCriticalRegion { state in
            if state.isCancelled { return .rejected(job) }
            if let consumer = state.waitingConsumer {
                state.waitingConsumer = nil
                return .handedToConsumer(consumer, job)
            }
            state.pending.append(job)
            return .queued
        }
        switch added {
            case .queued: break
            case .handedToConsumer(let consumer, let job): consumer.resume(returning: job)
            case .rejected(let job): job.cancel()
        }
    }

    /// Cancels the queue: the jobs that haven't started resume their awaiters with `CancellationError`, outside the
    /// lock, and the consumer stops.
    private static func cancel(_ state: CriticalState<State>) {
        let (unstarted, consumer) = state.withCriticalRegion { state in
            let consumer = state.waitingConsumer
            state.waitingConsumer = nil
            return (state.cancel(), consumer)
        }
        consumer?.resume(returning: nil)
        for job in unstarted { job.cancel() }
    }

    /// Queues a task to be executed serially without waiting for completion (fire-and-forget).
    ///
    /// If no task is currently running, the provided task is executed immediately.
    /// If a task is running, the provided task is added to the queue and will be executed once the current task completes.
    /// This method returns immediately without waiting for the task to complete.
    /// Any errors thrown by the task are silently ignored, and a task queued after ``cancelAll()`` doesn't run.
    ///
    /// - Parameter task: The asynchronous throwing task to be queued and executed.
    public func enqueue(_ task: sending @escaping () async throws -> Void) {
        add(Job(run: { try? await task() }, cancel: {}))
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
    public func enqueue<T>(_ task: sending @escaping () async throws -> sending T) async throws -> sending T {
        try await withUnsafeThrowingContinuation { continuation in
            add(
                Job(
                    run: {
                        do {
                            continuation.resume(returning: try await task())
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    },
                    cancel: { continuation.resume(throwing: CancellationError()) }))
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
        return try await enqueue { try await task() }
    }

    /// Cancels the running task and every queued task that hasn't started; those throw `CancellationError` to their
    /// awaiters, as does any task queued afterwards.
    public func cancelAll() {
        // The consumer first, so a job it has already taken sees the cancellation and doesn't start.
        consumer.cancel()
        Self.cancel(state)
    }
}
