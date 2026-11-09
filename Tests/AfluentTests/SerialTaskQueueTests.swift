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
                        // The one sleep in this file: a timer wait is what lets a second job overlap this one when
                        // the queue doesn't serialize. Without it a broken queue passes this test.
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
            // The stream never yields, so only cancelling the job ends its wait.
            let (neverYields, continuation) = AsyncStream<Void>.makeStream()
            let job = Task {
                try await queue.enqueue {
                    try sub.send()
                    for await _ in neverYields {}
                    try Task.checkCancellation()
                    executed.store(true, ordering: .sequentiallyConsistent)
                }
            }
            try await sub.execute()
            queue.cancelAll()
            let result = await job.result
            func getResult() throws { try result.get() }
            #expect(throws: CancellationError.self, performing: getResult)
            let actual = executed.load(ordering: .sequentiallyConsistent)
            #expect(actual == false)
            continuation.finish()
        }
    }

    @Test("Releasing the queue cancels the running job", .timeLimit(.minutes(1)))
    func queueCanCancelOngoingTasks_OnDeinit() async throws {
        let (started, startedContinuation) = AsyncStream<Void>.makeStream()
        // The job yields whether it saw cancellation once its wait ends.
        let (ended, endedContinuation) = AsyncStream<Bool>.makeStream()
        // The stream never yields, so only cancelling the job ends its wait.
        let (neverYields, neverYieldsContinuation) = AsyncStream<Void>.makeStream()
        var queue: SerialTaskQueue? = SerialTaskQueue()
        // A synchronous closure picks the fire-and-forget overload, which doesn't keep the queue alive.
        let enqueueWithoutWaiting = { (queue: SerialTaskQueue) in
            queue.enqueue {
                startedContinuation.yield()
                for await _ in neverYields {}
                endedContinuation.yield(Task.isCancelled)
            }
        }
        enqueueWithoutWaiting(try #require(queue))
        for await _ in started { break }

        queue = nil

        var sawCancellation: Bool?
        for await value in ended {
            sawCancellation = value
            break
        }
        #expect(sawCancellation == true)
        neverYieldsContinuation.finish()
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

        final class Capture: Sendable {}
        let ranAfterCancel = LockIsolated(false)
        weak var released: Capture?
        // A synchronous closure picks the fire-and-forget overload over the awaiting one.
        func enqueueWithoutWaiting() {
            let capture = Capture()
            released = capture
            queue.enqueue {
                _ = capture
                ranAfterCancel.setValue(true)
            }
        }
        enqueueWithoutWaiting()
        // A cancelled queue drops the job inside enqueue, so it can never run once its captures are gone.
        #expect(released == nil)
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

    @available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *)
    @Test(
        "A job still waiting to start at cancelAll() throws CancellationError to its awaiter",
        .timeLimit(.minutes(1)))
    func pendingJobThrowsCancellationErrorAtCancelAll() async throws {
        let queue = SerialTaskQueue()
        let (started, startedContinuation) = AsyncStream<Void>.makeStream()
        // The stream never yields, so only cancelling the running job ends its wait.
        let (neverYields, neverYieldsContinuation) = AsyncStream<Void>.makeStream()
        let running = Task {
            try await queue.enqueue {
                startedContinuation.yield()
                for await _ in neverYields {}
                try Task.checkCancellation()
            }
        }
        for await _ in started { break }
        // Runs synchronously until the job is queued and its awaiter suspends, so it is pending at cancelAll().
        let pending = Task.immediate { try await queue.enqueue { 1 } }

        queue.cancelAll()

        let pendingResult = await pending.result
        func getPendingResult() throws -> Int { try pendingResult.get() }
        #expect(throws: CancellationError.self, performing: getPendingResult)
        let runningResult = await running.result
        func getRunningResult() throws { try runningResult.get() }
        #expect(throws: CancellationError.self, performing: getRunningResult)
        neverYieldsContinuation.finish()
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

    @available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *)
    @Test(
        "Every job waiting at cancelAll() throws CancellationError to its awaiter",
        .timeLimit(.minutes(1)))
    func everyPendingJobThrowsCancellationErrorAtCancelAll() async throws {
        let queue = SerialTaskQueue()
        let (started, startedContinuation) = AsyncStream<Void>.makeStream()
        // The stream never yields, so only cancelling the running job ends its wait.
        let (neverYields, neverYieldsContinuation) = AsyncStream<Void>.makeStream()
        let running = Task {
            try await queue.enqueue {
                startedContinuation.yield()
                for await _ in neverYields {}
                try Task.checkCancellation()
            }
        }
        for await _ in started { break }
        let waiting = 8
        // Each runs synchronously until its job is queued, so all of them are pending at cancelAll().
        let pending = (0..<waiting).map { value in Task.immediate { try await queue.enqueue { value } } }

        queue.cancelAll()

        var cancelled = 0
        for job in pending {
            if case .failure(let error) = await job.result, error is CancellationError { cancelled += 1 }
        }
        #expect(cancelled == waiting)
        _ = await running.result
        neverYieldsContinuation.finish()
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

