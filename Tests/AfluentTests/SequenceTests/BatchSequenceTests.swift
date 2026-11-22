//
//  BatchSequenceTests.swift
//  Afluent
//

import Afluent
import AfluentTesting
import Atomics
import Clocks
import ConcurrencyExtras
import Foundation
import Testing

@Suite(.timeLimit(.minutes(1)))
struct BatchSequenceTests {
    // MARK: count

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("count(n) emits arrays of n, then the remainder when the upstream finishes")
    func countEmitsFullBatchesThenTheRemainder() async throws {
        let expected: [[Int]] = [[1, 2], [3, 4], [5]]

        var actual = [[Int]]()
        for try await batch in [1, 2, 3, 4, 5].async.batch(strategy: .count(2)) {
            actual.append(batch)
        }

        #expect(actual == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("count(n) over a multiple of n emits no trailing empty array")
    func countOverAMultipleEmitsNoEmptyArray() async throws {
        let expected: [[Int]] = [[1, 2], [3, 4]]

        var actual = [[Int]]()
        for try await batch in [1, 2, 3, 4].async.batch(strategy: .count(2)) {
            actual.append(batch)
        }

        #expect(actual == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("An empty upstream finishes with no batches")
    func emptyUpstreamEmitsNothing() async throws {
        let expected: [[Int]] = []

        var actual = [[Int]]()
        for try await batch in [Int]().async.batch(strategy: .count(3)) {
            actual.append(batch)
        }

        #expect(actual == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("One element short of the count is emitted when the upstream finishes")
    func oneElementIsEmittedOnFinish() async throws {
        let expected: [[Int]] = [[7]]

        var actual = [[Int]]()
        for try await batch in [7].async.batch(strategy: .count(3)) {
            actual.append(batch)
        }

        #expect(actual == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("count(1) emits every element in an array of its own")
    func countOfOneEmitsEachElementAlone() async throws {
        let expected: [[Int]] = [[1], [2], [3]]

        var actual = [[Int]]()
        for try await batch in [1, 2, 3].async.batch(strategy: .count(1)) {
            actual.append(batch)
        }

        #expect(actual == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("An upstream error drops the pending elements and is rethrown")
    func upstreamErrorDropsPendingAndRethrows() async throws {
        let (upstream, continuation) = AsyncThrowingStream<Int, any Error>.makeStream()
        continuation.yield(1)
        continuation.yield(2)
        continuation.yield(3)
        continuation.finish(throwing: GeneralError.e1)
        let expected: [[Int]] = [[1, 2]]

        var actual = [[Int]]()
        await #expect(throws: GeneralError.e1) {
            for try await batch in upstream.batch(strategy: .count(2)) {
                actual.append(batch)
            }
        }

        #expect(actual == expected)
    }

    // MARK: time

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("time(interval:) flushes the pending elements each time the interval passes")
    func timeFlushesOnTheInterval() async throws {
        let clock = TrackedTestClock()
        let (upstream, continuation) = AsyncStream<Int>.makeStream()
        let requests = ManagedAtomic(0)
        let batches = ManagedAtomic(0)
        let expected: [[Int]] = [[1, 2], [3]]
        let task = Task {
            var received = [[Int]]()
            let sut = upstream
                .handleEvents(receiveNext: { requests.wrappingIncrement(ordering: .sequentiallyConsistent) })
                .batch(strategy: .time(interval: .seconds(1), clock: clock))
            for try await batch in sut {
                received.append(batch)
                batches.wrappingIncrement(ordering: .sequentiallyConsistent)
            }
            return received
        }

        continuation.yield(1)
        continuation.yield(2)
        // A third request means the first two elements are pending.
        try await wait(until: requests.load(ordering: .sequentiallyConsistent) == 3, timeout: .seconds(2))
        try await clock.advance(by: .seconds(1), whenSleeping: 1)
        try await wait(until: batches.load(ordering: .sequentiallyConsistent) == 1, timeout: .seconds(2))
        continuation.yield(3)
        try await wait(until: requests.load(ordering: .sequentiallyConsistent) == 4, timeout: .seconds(2))
        try await clock.advance(by: .seconds(1), whenSleeping: 1)
        try await wait(until: batches.load(ordering: .sequentiallyConsistent) == 2, timeout: .seconds(2))
        continuation.finish()
        let actual = try await task.value

        #expect(actual == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("A timer that fires with nothing pending emits nothing and keeps timing")
    func timeWithNothingPendingEmitsNothing() async throws {
        let clock = TrackedTestClock()
        let (upstream, continuation) = AsyncStream<Int>.makeStream()
        let requests = ManagedAtomic(0)
        let batches = ManagedAtomic(0)
        let expected: [[Int]] = [[1]]
        let task = Task {
            var received = [[Int]]()
            let sut = upstream
                .handleEvents(receiveNext: { requests.wrappingIncrement(ordering: .sequentiallyConsistent) })
                .batch(strategy: .time(interval: .seconds(1), clock: clock))
            for try await batch in sut {
                received.append(batch)
                batches.wrappingIncrement(ordering: .sequentiallyConsistent)
            }
            return received
        }

        try await clock.advance(by: .seconds(1), whenSleeping: 1)
        try await clock.advance(by: .seconds(1), whenSleeping: 1)
        // Asleep again: the second firing, with nothing pending, is done.
        try await wait(until: clock.sleepingCount == 1, timeout: .seconds(2))
        continuation.yield(1)
        try await wait(until: requests.load(ordering: .sequentiallyConsistent) == 2, timeout: .seconds(2))
        try await clock.advance(by: .seconds(1), whenSleeping: 1)
        try await wait(until: batches.load(ordering: .sequentiallyConsistent) == 1, timeout: .seconds(2))
        continuation.finish()
        let actual = try await task.value

        #expect(actual == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("The timer doesn't fire before the interval passes")
    func timeDoesNotFireEarly() async throws {
        let clock = TrackedTestClock()
        let (upstream, continuation) = AsyncStream<Int>.makeStream()
        let requests = ManagedAtomic(0)
        let expected: [[Int]] = [[1, 2]]
        let task = Task {
            var received = [[Int]]()
            let sut = upstream
                .handleEvents(receiveNext: { requests.wrappingIncrement(ordering: .sequentiallyConsistent) })
                .batch(strategy: .time(interval: .seconds(1), clock: clock))
            for try await batch in sut {
                received.append(batch)
            }
            return received
        }

        continuation.yield(1)
        try await wait(until: requests.load(ordering: .sequentiallyConsistent) == 2, timeout: .seconds(2))
        try await clock.advance(by: .milliseconds(999), whenSleeping: 1)
        continuation.yield(2)
        try await wait(until: requests.load(ordering: .sequentiallyConsistent) == 3, timeout: .seconds(2))
        continuation.finish()
        let actual = try await task.value

        #expect(actual == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("A flush that lands before the timer starts listening still moves its first deadline")
    func flushBeforeTheTimerListensMovesItsDeadline() async throws {
        // The clock jumps 6 s and the batch flushes the first time the timer reads the time,
        // between that read and the timer's registration for flushes.
        let clock = ClockThatJumpsOnFirstRead(jump: .seconds(6))
        let flusher = LockIsolated<BatchFlusher?>(nil)
        clock.onFirstRead { flusher.value?.flush() }
        let gate = SingleValueSubject<Void>()
        let (upstream, continuation) = AsyncStream<Int>.makeStream()
        let requests = ManagedAtomic(0)
        let batches = ManagedAtomic(0)
        let expected: [[Int]] = [[1, 2], [3, 4]]
        let task = Task {
            var received = [[Int]]()
            let strategy = TimerAfterGate<Int>(
                timer: TimeBatchStrategy(interval: .seconds(10), clock: clock), gate: gate,
                flusher: flusher)
            let sut = upstream
                .handleEvents(receiveNext: { requests.wrappingIncrement(ordering: .sequentiallyConsistent) })
                .batch(strategy: strategy)
            for try await batch in sut {
                received.append(batch)
                batches.wrappingIncrement(ordering: .sequentiallyConsistent)
            }
            return received
        }

        continuation.yield(1)
        continuation.yield(2)
        try await wait(
            until: requests.load(ordering: .sequentiallyConsistent) == 3 && flusher.value != nil,
            timeout: .seconds(2))
        try gate.send()
        try await wait(until: batches.load(ordering: .sequentiallyConsistent) == 1, timeout: .seconds(2))
        try await wait(until: clock.base.sleepingCount == 1, timeout: .seconds(2))
        continuation.yield(3)
        try await wait(until: requests.load(ordering: .sequentiallyConsistent) == 4, timeout: .seconds(2))
        // 10 s on the clock: the first deadline had the flush at 6 s not moved it.
        try await clock.base.advance(by: .seconds(4), whenSleeping: 1)
        try await wait(until: clock.base.sleepingCount == 1, timeout: .seconds(2))
        continuation.yield(4)
        try await wait(until: requests.load(ordering: .sequentiallyConsistent) == 5, timeout: .seconds(2))
        continuation.finish()
        let actual = try await task.value

        #expect(actual == expected)
    }

    // MARK: signal

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("signal flushes on each value a PassthroughSubject sends")
    func signalFlushesOnPassthroughSubject() async throws {
        let flush = PassthroughSubject<Void>()
        let (upstream, continuation) = AsyncStream<Int>.makeStream()
        let requests = ManagedAtomic(0)
        let signalRequests = ManagedAtomic(0)
        let batches = ManagedAtomic(0)
        let expected: [[Int]] = [[1, 2], [3]]
        let task = Task {
            var received = [[Int]]()
            let signal = flush.handleEvents(receiveNext: {
                signalRequests.wrappingIncrement(ordering: .sequentiallyConsistent)
            })
            let sut = upstream
                .handleEvents(receiveNext: { requests.wrappingIncrement(ordering: .sequentiallyConsistent) })
                .batch(strategy: .signal(signal))
            for try await batch in sut {
                received.append(batch)
                batches.wrappingIncrement(ordering: .sequentiallyConsistent)
            }
            return received
        }

        // The first request on the signal means the subject has its subscriber.
        try await wait(until: signalRequests.load(ordering: .sequentiallyConsistent) == 1, timeout: .seconds(2))
        continuation.yield(1)
        continuation.yield(2)
        try await wait(until: requests.load(ordering: .sequentiallyConsistent) == 3, timeout: .seconds(2))
        flush.send()
        try await wait(until: batches.load(ordering: .sequentiallyConsistent) == 1, timeout: .seconds(2))
        continuation.yield(3)
        try await wait(until: requests.load(ordering: .sequentiallyConsistent) == 4, timeout: .seconds(2))
        flush.send()
        try await wait(until: batches.load(ordering: .sequentiallyConsistent) == 2, timeout: .seconds(2))
        continuation.finish()
        let actual = try await task.value

        #expect(actual == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("signal flushes on each value a CurrentValueSubject sends, and its current value flushes nothing")
    func signalFlushesOnCurrentValueSubject() async throws {
        let flush = CurrentValueSubject<Int>(0)
        let (upstream, continuation) = AsyncStream<Int>.makeStream()
        let requests = ManagedAtomic(0)
        let signalRequests = ManagedAtomic(0)
        let batches = ManagedAtomic(0)
        let expected: [[Int]] = [[1, 2], [3]]
        let task = Task {
            var received = [[Int]]()
            let signal = flush.handleEvents(receiveNext: {
                signalRequests.wrappingIncrement(ordering: .sequentiallyConsistent)
            })
            let sut = upstream
                .handleEvents(receiveNext: { requests.wrappingIncrement(ordering: .sequentiallyConsistent) })
                .batch(strategy: .signal(signal))
            for try await batch in sut {
                received.append(batch)
                batches.wrappingIncrement(ordering: .sequentiallyConsistent)
            }
            return received
        }

        // A second request on the signal means its current value has fired, with nothing pending.
        try await wait(until: signalRequests.load(ordering: .sequentiallyConsistent) == 2, timeout: .seconds(2))
        continuation.yield(1)
        continuation.yield(2)
        try await wait(until: requests.load(ordering: .sequentiallyConsistent) == 3, timeout: .seconds(2))
        flush.send(1)
        try await wait(until: batches.load(ordering: .sequentiallyConsistent) == 1, timeout: .seconds(2))
        continuation.yield(3)
        try await wait(until: requests.load(ordering: .sequentiallyConsistent) == 4, timeout: .seconds(2))
        flush.send(2)
        try await wait(until: batches.load(ordering: .sequentiallyConsistent) == 2, timeout: .seconds(2))
        continuation.finish()
        let actual = try await task.value

        #expect(actual == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("signal flushes once when a SingleValueSubject is sent a value")
    func signalFlushesOnceOnSingleValueSubject() async throws {
        let flush = SingleValueSubject<Void>()
        let (upstream, continuation) = AsyncStream<Int>.makeStream()
        let requests = ManagedAtomic(0)
        let batches = ManagedAtomic(0)
        let expected: [[Int]] = [[1, 2], [3, 4]]
        let task = Task {
            var received = [[Int]]()
            let sut = upstream
                .handleEvents(receiveNext: { requests.wrappingIncrement(ordering: .sequentiallyConsistent) })
                .batch(strategy: .signal(flush))
            for try await batch in sut {
                received.append(batch)
                batches.wrappingIncrement(ordering: .sequentiallyConsistent)
            }
            return received
        }

        continuation.yield(1)
        continuation.yield(2)
        try await wait(until: requests.load(ordering: .sequentiallyConsistent) == 3, timeout: .seconds(2))
        try flush.send()
        try await wait(until: batches.load(ordering: .sequentiallyConsistent) == 1, timeout: .seconds(2))
        continuation.yield(3)
        continuation.yield(4)
        continuation.finish()
        let actual = try await task.value

        #expect(actual == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("A SingleValueSubject of an optional type fires once, then the count alone batches")
    func optionalSingleValueSubjectFiresOnce() async throws {
        let flush = SingleValueSubject<Int?>()
        let flushes = ManagedAtomic(0)
        let (upstream, continuation) = AsyncStream<Int>.makeStream()
        let requests = ManagedAtomic(0)
        let expected: [[Int]] = [[1, 2, 3], [4, 5, 6]]
        let task = Task {
            var received = [[Int]]()
            let sut = upstream
                .handleEvents(receiveNext: { requests.wrappingIncrement(ordering: .sequentiallyConsistent) })
                .batch(strategy: .either(.signal(flush), .count(3), CountsFlushes(flushes: flushes)))
            for try await batch in sut {
                received.append(batch)
            }
            return received
        }

        // Registered (its observer runs once at once), then the signal's one flush.
        try await wait(until: flushes.load(ordering: .sequentiallyConsistent) == 1, timeout: .seconds(2))
        try flush.send(nil)
        try await wait(until: flushes.load(ordering: .sequentiallyConsistent) == 2, timeout: .seconds(2))
        // One element at a time, so a signal that kept firing would split the batches.
        for element in 1...6 {
            continuation.yield(element)
            try await wait(
                until: requests.load(ordering: .sequentiallyConsistent) == element + 1,
                timeout: .seconds(2))
        }
        continuation.finish()
        let actual = try await task.value

        #expect(actual == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("One SingleValueSubject strategy value fires again in each batched sequence it batches")
    func reusedSingleValueSubjectStrategyFiresInEachIteration() async throws {
        let flush = SingleValueSubject<Void>()
        let strategy: SignalBatchStrategy<Int, Deferred<AsyncThrowingStream<Void, any Error>>> =
            .signal(flush)
        let expected: [[[Int]]] = [[[1], [2]], [[1], [2]]]
        try flush.send()
        // Counts flushes from before the signal subscribes, and waits for the registration call
        // and the signal's flush before the first element, so that flush can't split a batch.
        func batches() async throws -> [[Int]] {
            let flushes = ManagedAtomic(0)
            let (upstream, continuation) = AsyncStream<Int>.makeStream()
            let task = Task {
                var received = [[Int]]()
                for try await batch in upstream.batch(
                    strategy: .either(.count(1), CountsFlushes(flushes: flushes, inner: strategy)))
                {
                    received.append(batch)
                }
                return received
            }
            try await wait(until: flushes.load(ordering: .sequentiallyConsistent) == 2, timeout: .seconds(2))
            continuation.yield(1)
            try await wait(until: flushes.load(ordering: .sequentiallyConsistent) == 3, timeout: .seconds(2))
            continuation.yield(2)
            continuation.finish()
            return try await task.value
        }

        let actual = [try await batches(), try await batches()]

        #expect(actual == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("One unit-of-work strategy value runs its unit again in each batched sequence it batches")
    func reusedUnitOfWorkStrategyRunsInEachIteration() async throws {
        let runs = ManagedAtomic(0)
        let unit = DeferredTask { runs.wrappingIncrement(ordering: .sequentiallyConsistent) }
        let strategy: SignalBatchStrategy<Int, Deferred<AsyncThrowingStream<Void, any Error>>> =
            .signal(unit)
        let expected: [[[Int]]] = [[[1], [2]], [[1], [2]]]
        let expectedRuns = 2
        // Counts flushes from before the signal subscribes, and waits for the registration call
        // and the signal's flush before the first element, so that flush can't split a batch.
        func batches() async throws -> [[Int]] {
            let flushes = ManagedAtomic(0)
            let (upstream, continuation) = AsyncStream<Int>.makeStream()
            let task = Task {
                var received = [[Int]]()
                for try await batch in upstream.batch(
                    strategy: .either(.count(1), CountsFlushes(flushes: flushes, inner: strategy)))
                {
                    received.append(batch)
                }
                return received
            }
            try await wait(until: flushes.load(ordering: .sequentiallyConsistent) == 2, timeout: .seconds(2))
            continuation.yield(1)
            try await wait(until: flushes.load(ordering: .sequentiallyConsistent) == 3, timeout: .seconds(2))
            continuation.yield(2)
            continuation.finish()
            return try await task.value
        }

        let actual = [try await batches(), try await batches()]

        #expect(actual == expected)
        #expect(runs.load(ordering: .sequentiallyConsistent) == expectedRuns)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("A SingleValueSubject sent an error ends the batched sequence with it")
    func singleValueSubjectErrorEndsTheSequence() async throws {
        let flush = SingleValueSubject<Void>()
        let (upstream, continuation) = AsyncStream<Int>.makeStream()
        defer { continuation.finish() }
        try flush.send(error: GeneralError.e1)

        let result = await Task {
            for try await _ in upstream.batch(strategy: .signal(flush)) {}
        }.result

        #expect(throws: GeneralError.e1) { try result.get() }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("A unit of work that fails as a signal ends the batched sequence with its error")
    func failingUnitOfWorkSignalEndsTheSequence() async throws {
        let (upstream, continuation) = AsyncStream<Int>.makeStream()
        defer { continuation.finish() }
        let signal = DeferredTask<Void> { throw GeneralError.e1 }

        let result = await Task {
            for try await _ in upstream.batch(strategy: .signal(signal)) {}
        }.result

        #expect(throws: GeneralError.e1) { try result.get() }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("A finished batched sequence leaves its SingleValueSubject pending for other awaiters")
    func finishingLeavesTheSingleValueSubjectPending() async throws {
        let flush = SingleValueSubject<Int>()
        let expectedBatches: [[Int]] = [[1, 2, 3]]
        let expectedValue = 5

        var actualBatches = [[Int]]()
        for try await batch in [1, 2, 3].async.batch(strategy: .signal(flush)) {
            actualBatches.append(batch)
        }
        try flush.send(expectedValue)
        let actual = try await flush.execute()

        #expect(actualBatches == expectedBatches)
        #expect(actual == expectedValue)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("Once the batch ends, its internal task ends too while a SingleValueSubject signal is still unsent")
    func internalTaskEndsWhileTheSubjectIsUnsent() async throws {
        let subject = SingleValueSubject<Void>()
        let released = SingleValueSubject<Void>()
        let expected: [[Int]] = [[1, 2]]
        // Only the batch holds the upstream, and its internal task holds it until it ends.
        func batches() async throws -> [[Int]] {
            var received = [[Int]]()
            let upstream = ReportsRelease(elements: [1, 2], released: released)
            for try await batch in upstream.batch(strategy: .signal(subject)) {
                received.append(batch)
            }
            return received
        }

        let actual = try await batches()
        try await released.execute()

        #expect(actual == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("A unit of work whose wait ignores cancellation keeps the internal task waiting after the batch ends")
    func unitOfWorkSignalThatIgnoresCancellationKeepsWaiting() async throws {
        let flush = SingleValueSubject<Int>()
        let waiting = SingleValueSubject<Void>()
        let waitEnded = SingleValueSubject<Void>()
        // Not a SingleValueSubject but a unit of work around one, so the generic overload runs it
        // through toAsyncSequence(): its wait ignores cancellation, so once the batch ends it only
        // returns when the subject is sent, and then reports the cancellation.
        let signal = flush.handleEvents(
            receiveOperation: { try? waiting.send() },
            receiveCancel: { try? waitEnded.send() })
        let (upstream, continuation) = AsyncStream<Int>.makeStream()
        let expectedBatches: [[Int]] = [[1]]
        let expectedValue = 5
        let task = Task {
            var received = [[Int]]()
            for try await batch in upstream.batch(strategy: .signal(signal)) {
                received.append(batch)
            }
            return received
        }

        try await waiting.execute()
        continuation.yield(1)
        continuation.finish()
        let actualBatches = try await task.value
        try flush.send(expectedValue)
        try await waitEnded.execute()
        let actual = try await flush.execute()

        #expect(actualBatches == expectedBatches)
        #expect(actual == expectedValue)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("A signal that finishes stops firing, and the batches go on until the upstream finishes")
    func finishedSignalStopsFiring() async throws {
        let (signal, signalContinuation) = AsyncStream<Void>.makeStream()
        signalContinuation.finish()
        let expected: [[Int]] = [[1, 2], [3]]

        var actual = [[Int]]()
        for try await batch in [1, 2, 3].async.batch(strategy: .either(.count(2), .signal(signal))) {
            actual.append(batch)
        }

        #expect(actual == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("A signal that throws ends the batched sequence with its error and drops the pending elements")
    func throwingSignalEndsTheSequence() async throws {
        let (upstream, continuation) = AsyncStream<Int>.makeStream()
        let (signal, signalContinuation) = AsyncThrowingStream<Void, any Error>.makeStream()
        let requests = ManagedAtomic(0)
        let batches = ManagedAtomic(0)
        let upstreamEnded = SingleValueSubject<Void>()
        continuation.onTermination = { _ in try? upstreamEnded.send() }
        let expectedBatches = 0
        let task = Task {
            let sut = upstream
                .handleEvents(receiveNext: { requests.wrappingIncrement(ordering: .sequentiallyConsistent) })
                .batch(strategy: .signal(signal))
            for try await _ in sut {
                batches.wrappingIncrement(ordering: .sequentiallyConsistent)
            }
        }

        continuation.yield(1)
        try await wait(until: requests.load(ordering: .sequentiallyConsistent) == 2, timeout: .seconds(2))
        signalContinuation.finish(throwing: GeneralError.e1)
        let result = await task.result
        try await upstreamEnded.execute()
        let actualBatches = batches.load(ordering: .sequentiallyConsistent)

        #expect(throws: GeneralError.e1) { try result.get() }
        #expect(actualBatches == expectedBatches)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("A SingleValueSubject that someone else cancels stops firing, and the batches go on")
    func cancelledSingleValueSubjectStopsFiring() async throws {
        let flush = SingleValueSubject<Void>()
        flush.cancel()
        let expected: [[Int]] = [[1, 2], [3]]

        var actual = [[Int]]()
        for try await batch in [1, 2, 3].async.batch(strategy: .either(.count(2), .signal(flush))) {
            actual.append(batch)
        }

        #expect(actual == expected)
    }

    // MARK: either

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("either flushes on whichever of a count and a signal fires")
    func eitherFlushesOnCountOrSignal() async throws {
        let flush = PassthroughSubject<Void>()
        let (upstream, continuation) = AsyncStream<Int>.makeStream()
        let requests = ManagedAtomic(0)
        let signalRequests = ManagedAtomic(0)
        let batches = ManagedAtomic(0)
        let expected: [[Int]] = [[1, 2, 3], [4], [5, 6, 7], [8]]
        let task = Task {
            var received = [[Int]]()
            let signal = flush.handleEvents(receiveNext: {
                signalRequests.wrappingIncrement(ordering: .sequentiallyConsistent)
            })
            let sut = upstream
                .handleEvents(receiveNext: { requests.wrappingIncrement(ordering: .sequentiallyConsistent) })
                .batch(strategy: .either(.count(3), .signal(signal)))
            for try await batch in sut {
                received.append(batch)
                batches.wrappingIncrement(ordering: .sequentiallyConsistent)
            }
            return received
        }

        try await wait(until: signalRequests.load(ordering: .sequentiallyConsistent) == 1, timeout: .seconds(2))
        for element in 1...4 { continuation.yield(element) }
        try await wait(until: requests.load(ordering: .sequentiallyConsistent) == 5, timeout: .seconds(2))
        flush.send()
        try await wait(until: batches.load(ordering: .sequentiallyConsistent) == 2, timeout: .seconds(2))
        // The signal's flush started the count over: three more make a full batch.
        for element in 5...8 { continuation.yield(element) }
        continuation.finish()
        let actual = try await task.value

        #expect(actual == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("either restarts the timer when the count flushes")
    func eitherRestartsTheTimerOnACountFlush() async throws {
        let clock = TrackedTestClock()
        let (upstream, continuation) = AsyncStream<Int>.makeStream()
        let requests = ManagedAtomic(0)
        let batches = ManagedAtomic(0)
        let expected: [[Int]] = [[1, 2], [3]]
        let task = Task {
            var received = [[Int]]()
            let sut = upstream
                .handleEvents(receiveNext: { requests.wrappingIncrement(ordering: .sequentiallyConsistent) })
                .batch(strategy: .either(.count(2), .time(interval: .seconds(10), clock: clock)))
            for try await batch in sut {
                received.append(batch)
                batches.wrappingIncrement(ordering: .sequentiallyConsistent)
            }
            return received
        }

        try await clock.advance(by: .seconds(6), whenSleeping: 1)
        continuation.yield(1)
        continuation.yield(2)
        try await wait(until: batches.load(ordering: .sequentiallyConsistent) == 1, timeout: .seconds(2))
        continuation.yield(3)
        try await wait(until: requests.load(ordering: .sequentiallyConsistent) == 4, timeout: .seconds(2))
        // 12 s in: past the first deadline, but only 6 s after the count's flush.
        try await clock.advance(by: .seconds(6), whenSleeping: 1)
        try await wait(until: clock.sleepingCount == 1, timeout: .seconds(2))
        let expectedBatchesBeforeTheNewDeadline = 1
        let batchesBeforeTheNewDeadline = batches.load(ordering: .sequentiallyConsistent)
        try await clock.advance(by: .seconds(4), whenSleeping: 1)
        try await wait(until: batches.load(ordering: .sequentiallyConsistent) == 2, timeout: .seconds(2))
        continuation.finish()
        let actual = try await task.value

        #expect(batchesBeforeTheNewDeadline == expectedBatchesBeforeTheNewDeadline)
        #expect(actual == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("either starts the count over when the timer flushes")
    func eitherRestartsTheCountOnATimerFlush() async throws {
        let clock = TrackedTestClock()
        let (upstream, continuation) = AsyncStream<Int>.makeStream()
        let requests = ManagedAtomic(0)
        let batches = ManagedAtomic(0)
        let expected: [[Int]] = [[1, 2], [3, 4, 5], [6]]
        let task = Task {
            var received = [[Int]]()
            let sut = upstream
                .handleEvents(receiveNext: { requests.wrappingIncrement(ordering: .sequentiallyConsistent) })
                .batch(strategy: .either(.count(3), .time(interval: .seconds(10), clock: clock)))
            for try await batch in sut {
                received.append(batch)
                batches.wrappingIncrement(ordering: .sequentiallyConsistent)
            }
            return received
        }

        continuation.yield(1)
        continuation.yield(2)
        try await wait(until: requests.load(ordering: .sequentiallyConsistent) == 3, timeout: .seconds(2))
        try await clock.advance(by: .seconds(10), whenSleeping: 1)
        try await wait(until: batches.load(ordering: .sequentiallyConsistent) == 1, timeout: .seconds(2))
        for element in 3...6 { continuation.yield(element) }
        continuation.finish()
        let actual = try await task.value

        #expect(actual == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("A signal that throws inside either ends the batched sequence at once, though a timer still waits")
    func throwingSignalInEitherEndsAtOnce() async throws {
        let clock = TrackedTestClock()
        let (signal, signalContinuation) = AsyncThrowingStream<Void, any Error>.makeStream()
        signalContinuation.finish(throwing: GeneralError.e1)
        let (upstream, continuation) = AsyncStream<Int>.makeStream()
        defer { continuation.finish() }

        let result = await Task {
            let sut = upstream.batch(
                strategy: .either(.signal(signal), .time(interval: .seconds(100), clock: clock)))
            for try await _ in sut {}
        }.result

        #expect(throws: GeneralError.e1) { try result.get() }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("The shorthand spelling infers the element from the upstream")
    func shorthandSpellingInfersTheElement() async throws {
        let expected: [[Int]] = [[1, 2, 3], [4]]

        var actual = [[Int]]()
        for try await batch in [1, 2, 3, 4].async.batch(strategy: .either(.count(3), .time(interval: .seconds(1), clock: ContinuousClock()))) {
            actual.append(batch)
        }

        #expect(actual == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("Strategies spelled with their types batch the same as the shorthand")
    func explicitSpellingsBatchTheSame() async throws {
        let strategy: EitherBatchStrategy<Int> = .either(.count(2), CountBatchStrategy(5))
        let named = EitherBatchStrategy<Int>(CountBatchStrategy(2))
        let expected: [[Int]] = [[1, 2], [3]]

        var actual = [[Int]]()
        for try await batch in [1, 2, 3].async.batch(strategy: strategy) { actual.append(batch) }
        var actualNamed = [[Int]]()
        for try await batch in [1, 2, 3].async.batch(strategy: named) { actualNamed.append(batch) }

        #expect(actual == expected)
        #expect(actualNamed == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("either with the smaller of two counts flushes at the smaller")
    func eitherOfTwoCountsFlushesAtTheSmaller() async throws {
        let expected: [[Int]] = [[1, 2], [3, 4], [5]]

        var actual = [[Int]]()
        for try await batch in [1, 2, 3, 4, 5].async.batch(strategy: .either(.count(5), .count(2))) {
            actual.append(batch)
        }

        #expect(actual == expected)
    }

    // MARK: cancellation

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("Cancelling the consumer cancels the upstream, the timer and the signal subscriptions")
    func cancellingTheConsumerCancelsEverything() async throws {
        let clock = TrackedTestClock()
        let (upstream, continuation) = AsyncStream<Int>.makeStream()
        let (signal, signalContinuation) = AsyncStream<Void>.makeStream()
        let subject = SingleValueSubject<Int>()
        let upstreamEnded = SingleValueSubject<Void>()
        let signalEnded = SingleValueSubject<Void>()
        continuation.onTermination = { _ in try? upstreamEnded.send() }
        signalContinuation.onTermination = { _ in try? signalEnded.send() }
        let requests = ManagedAtomic(0)
        let signalRequests = ManagedAtomic(0)
        let expectedValue = 9
        let task = Task {
            let sut = upstream
                .handleEvents(receiveNext: { requests.wrappingIncrement(ordering: .sequentiallyConsistent) })
                .batch(
                    strategy: .either(
                        .time(interval: .seconds(1), clock: clock),
                        .signal(
                            signal.handleEvents(receiveNext: {
                                signalRequests.wrappingIncrement(ordering: .sequentiallyConsistent)
                            })),
                        .signal(subject)))
            for try await _ in sut {}
        }
        try await wait(
            until: requests.load(ordering: .sequentiallyConsistent) == 1
                && signalRequests.load(ordering: .sequentiallyConsistent) == 1
                && clock.sleepingCount == 1,
            timeout: .seconds(2))

        task.cancel()
        _ = await task.result
        try await upstreamEnded.execute()
        try await signalEnded.execute()
        try await wait(until: clock.sleepingCount == 0, timeout: .seconds(2))
        try subject.send(expectedValue)
        let actual = try await subject.execute()

        #expect(actual == expectedValue)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("After the consumer cancels, an upstream that ignores cancellation is not read again")
    func cancelledBatchStopsReadingANonCooperativeUpstream() async throws {
        let upstream = IgnoresCancellation()
        let expectedPulls = 1
        let task = Task {
            for try await _ in upstream.batch(strategy: .count(10)) {}
        }
        try await wait(
            until: upstream.pulls.load(ordering: .sequentiallyConsistent) == 1
                && upstream.pending.value != nil,
            timeout: .seconds(2))

        task.cancel()
        _ = await task.result
        let pending = upstream.pending.withValue { pending in
            defer { pending = nil }
            return pending
        }
        pending?.resume(returning: 1)
        // The iterator is released once the batch stops reading, rather than asked for more.
        try await upstream.iteratorReleased.execute()
        let actualPulls = upstream.pulls.load(ordering: .sequentiallyConsistent)

        #expect(actualPulls == expectedPulls)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("When the upstream finishes, the timer and the signal subscriptions end")
    func finishingEndsTheTimerAndSignals() async throws {
        let clock = TrackedTestClock()
        let (upstream, continuation) = AsyncStream<Int>.makeStream()
        let (signal, signalContinuation) = AsyncStream<Void>.makeStream()
        let signalEnded = SingleValueSubject<Void>()
        signalContinuation.onTermination = { _ in try? signalEnded.send() }
        let signalRequests = ManagedAtomic(0)
        let expected: [[Int]] = [[1]]
        let task = Task {
            var received = [[Int]]()
            let sut = upstream.batch(
                strategy: .either(
                    .time(interval: .seconds(1), clock: clock),
                    .signal(
                        signal.handleEvents(receiveNext: {
                            signalRequests.wrappingIncrement(ordering: .sequentiallyConsistent)
                        }))))
            for try await batch in sut {
                received.append(batch)
            }
            return received
        }
        try await wait(
            until: signalRequests.load(ordering: .sequentiallyConsistent) == 1 && clock.sleepingCount == 1,
            timeout: .seconds(2))

        continuation.yield(1)
        continuation.finish()
        let actual = try await task.value
        try await signalEnded.execute()
        try await wait(until: clock.sleepingCount == 0, timeout: .seconds(2))

        #expect(actual == expected)
    }
}

/// An endless upstream whose `next()` waits for the test to hand it an element and ignores
/// cancellation, and that reports when its iterator is released.
private struct IgnoresCancellation: AsyncSequence, Sendable {
    let pulls = ManagedAtomic(0)
    let pending = LockIsolated<UnsafeContinuation<Int, Never>?>(nil)
    let iteratorReleased = SingleValueSubject<Void>()

    final class Release: Sendable {
        let released: SingleValueSubject<Void>
        init(_ released: SingleValueSubject<Void>) { self.released = released }
        deinit { try? released.send() }
    }

    struct AsyncIterator: AsyncIteratorProtocol {
        let sequence: IgnoresCancellation
        let release: Release

        mutating func next() async -> Int? {
            sequence.pulls.wrappingIncrement(ordering: .sequentiallyConsistent)
            let sequence = sequence
            return await withUnsafeContinuation { continuation in
                sequence.pending.setValue(continuation)
            }
        }
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(sequence: self, release: Release(iteratorReleased))
    }
}

/// A strategy that hands its flusher to the test, waits for a gate, then runs a timer.
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
private struct TimerAfterGate<Element>: BatchStrategy {
    let timer: TimeBatchStrategy<Element, ClockThatJumpsOnFirstRead>
    let gate: SingleValueSubject<Void>
    let flusher: LockIsolated<BatchFlusher?>

    func run(_ flusher: BatchFlusher) async throws {
        self.flusher.setValue(flusher)
        try await gate.execute()
        try await timer.run(flusher)
    }
}

/// A tracked test clock whose time, the first time it is read, jumps ahead and runs a hook, then
/// returns the time from before the jump.
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
private final class ClockThatJumpsOnFirstRead: Clock, @unchecked Sendable {
    typealias Duration = Swift.Duration
    typealias Instant = TrackedTestClock.Instant

    let base = TrackedTestClock()
    private let jump: Duration
    private let lock = NSLock()
    private var offset = Duration.zero
    private var hook: (@Sendable () -> Void)?

    init(jump: Duration) {
        self.jump = jump
    }

    func onFirstRead(_ hook: @escaping @Sendable () -> Void) {
        lock.withLock { self.hook = hook }
    }

    var now: Instant {
        let (current, hook): (Instant, (@Sendable () -> Void)?) = lock.withLock {
            let current = base.now.advanced(by: offset)
            let hook = self.hook
            if hook != nil {
                self.hook = nil
                offset += jump
            }
            return (current, hook)
        }
        hook?()
        return current
    }

    var minimumResolution: Duration { .zero }

    func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws {
        let offset = lock.withLock { self.offset }
        try await base.sleep(until: deadline.advanced(by: .zero - offset), tolerance: tolerance)
    }
}

/// A sequence of fixed elements that reports when it is released.
private final class ReportsRelease: AsyncSequence, Sendable {
    let elements: [Int]
    let released: SingleValueSubject<Void>

    init(elements: [Int], released: SingleValueSubject<Void>) {
        self.elements = elements
        self.released = released
    }

    deinit { try? released.send() }

    func makeAsyncIterator() -> IndexingIterator<[Int]>.AsyncIterator {
        IndexingIterator<[Int]>.AsyncIterator(elements: elements)
    }
}

extension IndexingIterator<[Int]> {
    /// Iterates fixed elements without holding the sequence that made it.
    fileprivate struct AsyncIterator: AsyncIteratorProtocol {
        let elements: [Int]
        var index = 0

        mutating func next() async -> Int? {
            guard index < elements.count else { return nil }
            defer { index += 1 }
            return elements[index]
        }
    }
}

/// Counts the flushes it hears of, including the call when it starts listening, then runs
/// `inner`, if given, so none of `inner`'s flushes go uncounted.
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
private struct CountsFlushes<Element>: BatchStrategy {
    let flushes: ManagedAtomic<Int>
    var inner: (any BatchStrategy<Element>)? = nil

    func flushes(pending: [Element]) -> Bool {
        inner?.flushes(pending: pending) ?? false
    }

    func run(_ flusher: BatchFlusher) async throws {
        let flushes = flushes
        flusher.onFlush { flushes.wrappingIncrement(ordering: .sequentiallyConsistent) }
        try await inner?.run(flusher)
    }
}
