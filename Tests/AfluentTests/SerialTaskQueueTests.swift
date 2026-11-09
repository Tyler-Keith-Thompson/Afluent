import Afluent
//
//  SerialTaskQueueTests.swift
//
//
//  Created by Tyler Thompson on 6/30/24.
//
import Atomics
import ConcurrencyExtras
import Testing

struct SerialTaskQueueTests {
    @Test func serialTaskQueueSchedulesOneTaskAtATime_EvenWhenSchedulingIsConcurrent() async throws
    {
        let queue = SerialTaskQueue()
        actor Test {
            var isExecuting = false

            func store(_ val: Bool) {
                isExecuting = val
            }
        }
        let test = Test()
        let results = try await withThrowingTaskGroup(of: Int.self, returning: [Int].self) {
            group in
            for i in 1...100 {
                group.addTask {
                    try await queue.enqueue {
                        let executing = await test.isExecuting
                        #expect(executing == false)
                        await test.store(true)
                        try await Task.sleep(nanoseconds: 1)
                        await test.store(false)
                        return i
                    }
                }
            }

            var results = [Int]()
            for try await result in group {
                results.append(result)
            }
            return results
        }
        // Why sort the results? Because task groups don't make any guarantees, just because I asked it to schedule these in order doesn't mean it did.
        #expect(results.sorted() == Array(1...100))
    }

    @Test func queuingATaskThatThrows_ThrowsToQueue() async throws {
        enum Err: Error {
            case e1
        }
        let queue = SerialTaskQueue()
        let result = await Task {
            try await queue.enqueue {
                throw Err.e1
            }
        }.result
        #expect(
            throws: Err.self,
            performing: {
                try result.get()
            })
    }

    @Test func queuingATaskThatThrows_StillAllowsOthersToBeQueued() async throws {
        enum Err: Error {
            case e1
        }
        let queue = SerialTaskQueue()
        let result = await Task {
            try await queue.enqueue {
                throw Err.e1
            }
        }.result
        #expect(
            throws: Err.self,
            performing: {
                try result.get()
            })
        let result2 = try await queue.enqueue {
            2
        }
        #expect(result2 == 2)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(.timeLimit(.minutes(1)))
    func queueCanCancelOngoingTasks() async throws {
        try await withMainSerialExecutor {
            let sub = SingleValueSubject<Void>()
            let queue = SerialTaskQueue()
            let executed = ManagedAtomic(false)
            async let _: Void = try await queue.enqueue {
                try sub.send()
                try Task.checkCancellation()
                try await Task.sleep(for: .milliseconds(20))
                executed.store(true, ordering: .sequentiallyConsistent)
            }
            await Task.yield()
            try await sub.execute()
            queue.cancelAll()
            let actual = executed.load(ordering: .sequentiallyConsistent)
            #expect(actual == false)
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test func queueCanCancelOngoingTasks_OnDeinit() async throws {
        try await withMainSerialExecutor {
            let sub = SingleValueSubject<Void>()
            let cancelationSubject = SingleValueSubject<Void>()
            actor StateHolder {
                var queue: SerialTaskQueue? = SerialTaskQueue()
                func deinitQueue() {
                    queue = nil
                }
                func getQueue() throws -> SerialTaskQueue {
                    try #require(queue)
                }
            }
            let stateHolder = StateHolder()
            let executed = ManagedAtomic(false)
            async let _: Void = try await stateHolder.getQueue().enqueue {
                try sub.send()
                try await cancelationSubject.execute()
                try Task.checkCancellation()
                try await Task.sleep(for: .milliseconds(20))
                executed.store(true, ordering: .sequentiallyConsistent)
            }
            await Task.yield()
            try await sub.execute()
            await stateHolder.deinitQueue()
            try cancelationSubject.send()
            let actual = executed.load(ordering: .sequentiallyConsistent)
            #expect(actual == false)
        }
    }

    @Test func fireAndForgetEnqueueExecutesTasksSerially() async throws {
        let queue = SerialTaskQueue()
        actor Test {
            var executionOrder = [Int]()

            func addExecution(_ value: Int) {
                executionOrder.append(value)
            }

            func getExecutionOrder() -> [Int] {
                executionOrder
            }
        }
        let test = Test()
        let sub = SingleValueSubject<Void>()

        // Fire and forget multiple tasks - use non-throwing version
        for i in 1...3 {
            {queue.enqueue {
                await test.addExecution(i)
                if i == 3 {
                    try sub.send()
                }
            }}() // this is some stupid-ass cermony because Swift insists on preferring the async method since we're async. Despite the fact that doesn't compile.
        }

        // Wait a bit for all tasks to complete
        try await sub.execute()

        let executionOrder = await test.getExecutionOrder()
        #expect(executionOrder == [1, 2, 3])
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test("A queue nothing references any more is deallocated")
    func unreferencedQueueIsDeallocated() async throws {
        weak var released: SerialTaskQueue?
        do {
            let queue = SerialTaskQueue()
            released = queue
            let result = try await queue.enqueue { 1 }
            #expect(result == 1)
        }
        #expect(released == nil)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(
        "A job that cancels its queue just before returning still delivers its value once",
        .timeLimit(.minutes(1)))
    func jobCancellingItsQueueDeliversItsValueOnce() async throws {
        let queue = SerialTaskQueue()
        let expected = 1
        let result = try await queue.enqueue {
            queue.cancelAll()
            return expected
        }
        #expect(result == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(
        "cancelAll from several tasks at once returns, and work enqueued afterwards does not run",
        .timeLimit(.minutes(1)))
    func concurrentCancelAllStopsTheQueue() async throws {
        let queue = SerialTaskQueue()
        // A job that finishes shows the consumer is running before it is cancelled.
        let warmUp = 1
        let warmedUp = try await queue.enqueue { warmUp }
        #expect(warmedUp == warmUp)

        let cancellers = 16
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<cancellers {
                group.addTask { queue.cancelAll() }
            }
        }

        let ranAfterCancel = LockIsolated(false)
        // A synchronous closure picks the fire-and-forget overload over the awaiting one.
        let enqueueWithoutWaiting = { queue.enqueue { ranAfterCancel.setValue(true) } }
        enqueueWithoutWaiting()
        // Not running can only be checked within a bound; yielding gives a live consumer every
        // chance to pick the job up.
        let yields = 1_000
        for _ in 0..<yields {
            await Task.yield()
        }
        #expect(ranAfterCancel.value == false)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(
        "A job that cancels its own task doesn't stop the jobs after it", .timeLimit(.minutes(1)))
    func selfCancellingJobDoesNotStopTheQueue() async throws {
        let queue = SerialTaskQueue()
        @Sendable func cancelOwnTask() {
            withUnsafeCurrentTask { $0?.cancel() }
        }
        _ = try? await queue.enqueue { cancelOwnTask() }
        let expected = 2
        let second = try await queue.enqueue { expected }
        #expect(second == expected)
    }

    @Test("enqueue takes a task that captures a non-Sendable value and returns a non-Sendable value")
    func enqueueTakesANonSendableTask() async throws {
        final class Counter {
            var count = 0
        }
        let queue = SerialTaskQueue()
        let captured = Counter()
        let returned = try await queue.enqueue {
            captured.count += 1
            let result = Counter()
            result.count = captured.count
            return result
        }
        let expected = 1
        #expect(returned.count == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(
        "A job still waiting to start at cancelAll() throws CancellationError to its awaiter",
        .timeLimit(.minutes(1)))
    func pendingJobThrowsCancellationErrorAtCancelAll() async throws {
        await withMainSerialExecutor {
            let queue = SerialTaskQueue()
            let (started, startedContinuation) = AsyncStream<Void>.makeStream()
            let running = Task {
                try await queue.enqueue {
                    startedContinuation.yield()
                    try await Task.sleep(for: .seconds(3600))
                }
            }
            for await _ in started { break }
            let pending = Task { try await queue.enqueue { 1 } }
            await Task.megaYield()

            queue.cancelAll()

            let pendingResult = await pending.result
            #expect(throws: CancellationError.self) { try pendingResult.get() }
            let runningResult = await running.result
            #expect(throws: CancellationError.self) { try runningResult.get() }
        }
    }

    @Test("A job queued after cancelAll() throws CancellationError without running", .timeLimit(.minutes(1)))
    func jobQueuedAfterCancelAllThrowsCancellationError() async throws {
        let queue = SerialTaskQueue()
        queue.cancelAll()
        let ran = ManagedAtomic(false)
        let result = await Task {
            try await queue.enqueue { ran.store(true, ordering: .sequentiallyConsistent) }
        }.result
        #expect(throws: CancellationError.self) { try result.get() }
        let actual = ran.load(ordering: .sequentiallyConsistent)
        #expect(actual == false)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(
        "Every job waiting at cancelAll() throws CancellationError to its awaiter",
        .timeLimit(.minutes(1)))
    func everyPendingJobThrowsCancellationErrorAtCancelAll() async throws {
        await withMainSerialExecutor {
            let queue = SerialTaskQueue()
            let (started, startedContinuation) = AsyncStream<Void>.makeStream()
            let running = Task {
                try await queue.enqueue {
                    startedContinuation.yield()
                    try await Task.sleep(for: .seconds(3600))
                }
            }
            for await _ in started { break }
            let waiting = 8
            let pending = (0..<waiting).map { value in Task { try await queue.enqueue { value } } }
            await Task.megaYield()

            queue.cancelAll()

            var cancelled = 0
            for job in pending {
                if case .failure(let error) = await job.result, error is CancellationError { cancelled += 1 }
            }
            #expect(cancelled == waiting)
            _ = await running.result
        }
    }

    @Test(
        "A finished job whose captures call back into the queue when released doesn't deadlock it",
        .timeLimit(.minutes(1)))
    func releasingAFinishedJobsCapturesCanCallBackIntoTheQueue() async throws {
        final class EnqueuesOnDeinit: Sendable {
            let queue: SerialTaskQueue
            init(_ queue: SerialTaskQueue) { self.queue = queue }
            deinit { queue.enqueue {} }
        }
        // A synchronous caller picks the fire-and-forget overload over the awaiting one.
        func enqueueWithoutWaiting(_ queue: SerialTaskQueue, _ job: sending @escaping () async -> Void) {
            queue.enqueue(job)
        }
        let queue = SerialTaskQueue()
        let (gate, open) = AsyncStream<Void>.makeStream()
        enqueueWithoutWaiting(queue) {
            for await _ in gate { break }
        }
        do {
            let capture = EnqueuesOnDeinit(queue)
            enqueueWithoutWaiting(queue) { _ = capture }
        }
        enqueueWithoutWaiting(queue) {}
        open.yield()

        let expected = 3
        let last = try await queue.enqueue { expected }
        #expect(last == expected)
    }

    @Test(
        "A finished job's captures are released while later jobs still wait", .timeLimit(.minutes(1)))
    func finishedJobsCapturesAreReleasedWhileOthersWait() async throws {
        final class Capture: Sendable {}
        // A synchronous caller picks the fire-and-forget overload over the awaiting one.
        func enqueueWithoutWaiting(_ queue: SerialTaskQueue, _ job: sending @escaping () async -> Void) {
            queue.enqueue(job)
        }
        let queue = SerialTaskQueue()
        let (firstGate, openFirst) = AsyncStream<Void>.makeStream()
        let (thirdGate, openThird) = AsyncStream<Void>.makeStream()
        let (thirdStarted, thirdStartedContinuation) = AsyncStream<Void>.makeStream()
        enqueueWithoutWaiting(queue) {
            for await _ in firstGate { break }
        }
        weak var released: Capture?
        do {
            let capture = Capture()
            released = capture
            enqueueWithoutWaiting(queue) { _ = capture }
        }
        enqueueWithoutWaiting(queue) {
            thirdStartedContinuation.yield()
            for await _ in thirdGate { break }
        }
        enqueueWithoutWaiting(queue) {}
        openFirst.yield()
        for await _ in thirdStarted { break }

        #expect(released == nil)
        openThird.yield()
    }
}

