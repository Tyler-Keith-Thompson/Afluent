//
//  TaskStateTests.swift
//  Afluent
//

import ConcurrencyExtras
import Testing

@testable import Afluent

struct TaskStateTests {
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(
        "A task created while another thread cancels the state is always cancelled",
        .timeLimit(.minutes(1)))
    func taskCreatedConcurrentlyWithCancelIsCancelled() async throws {
        let iterations = 1_000
        for _ in 0..<iterations {
            let state = TaskState<Void>()
            // The task waits on a stream nothing yields to, so it finishes only once it is cancelled. A task the
            // state lost track of would never finish, and the time limit would fail the test.
            let creator = Task.detached {
                state.createTask(priority: nil) {
                    let (pending, keepOpen) = AsyncStream<Void>.makeStream()
                    for await _ in pending {}
                    keepOpen.finish()
                }
            }
            let canceller = Task.detached { state.cancel() }
            await canceller.value
            let created = await creator.value
            // If the state lost track of the task, the time limit cancels this test; cancelling the task here lets
            // the test report that failure and finish instead of waiting forever.
            _ = await withTaskCancellationHandler {
                await created.result
            } onCancel: {
                created.cancel()
            }
            if Task.isCancelled { break }
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(
        "Cancelling from inside the task's own cancellation handler finishes the task",
        .timeLimit(.minutes(1)))
    func cancelFromInsideCancellationHandlerFinishes() async throws {
        let state = TaskState<Void>()
        let (started, startedContinuation) = AsyncStream<Void>.makeStream()
        let task = state.createTask(priority: nil) {
            await withTaskCancellationHandler {
                startedContinuation.yield()
                let (pending, keepOpen) = AsyncStream<Void>.makeStream()
                for await _ in pending {}
                keepOpen.finish()
            } onCancel: {
                // Runs inline while the `cancel()` below cancels this task.
                state.cancel()
            }
        }
        for await _ in started { break }

        state.cancel()

        _ = await task.result
        #expect(state.isCancelled)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(
        "Concurrent calls to cancel each return, and the running task finishes",
        .timeLimit(.minutes(1)))
    func concurrentCancelsFinish() async throws {
        let state = TaskState<Void>()
        let (started, startedContinuation) = AsyncStream<Void>.makeStream()
        let task = state.createTask(priority: nil) {
            startedContinuation.yield()
            let (pending, keepOpen) = AsyncStream<Void>.makeStream()
            for await _ in pending {}
            keepOpen.finish()
        }
        for await _ in started { break }

        let cancellers = 64
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<cancellers {
                group.addTask { state.cancel() }
            }
        }

        _ = await task.result
        #expect(state.isCancelled)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(
        "A unit of work whose cancellation handler cancels the same work finishes",
        .timeLimit(.minutes(1)))
    func deferredTaskCancelledFromItsOwnCancellationHandlerFinishes() async throws {
        let (started, startedContinuation) = AsyncStream<Void>.makeStream()
        let handle = LockIsolated<DeferredTask<Void>?>(nil)
        let work = DeferredTask {
            await withTaskCancellationHandler {
                startedContinuation.yield()
                let (pending, keepOpen) = AsyncStream<Void>.makeStream()
                for await _ in pending {}
                keepOpen.finish()
            } onCancel: {
                handle.value?.cancel()
            }
        }
        handle.setValue(work)
        defer { handle.setValue(nil) }
        let execution = Task { try await work.execute() }
        for await _ in started { break }

        work.cancel()

        let result = await execution.result
        #expect(throws: CancellationError.self) { try result.get() }
    }
}
