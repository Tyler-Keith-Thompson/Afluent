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

    @Test("count(n) emits arrays of n, then the remainder when the upstream finishes")
    func countEmitsFullBatchesThenTheRemainder() async throws {
        let expected: [[Int]] = [[1, 2], [3, 4], [5]]

        var actual = [[Int]]()
        for try await batch in [1, 2, 3, 4, 5].async.batch(strategy: .count(2)) {
            actual.append(batch)
        }

        #expect(actual == expected)
    }

    @Test("count(n) over a multiple of n emits no trailing empty array")
    func countOverAMultipleEmitsNoEmptyArray() async throws {
        let expected: [[Int]] = [[1, 2], [3, 4]]

        var actual = [[Int]]()
        for try await batch in [1, 2, 3, 4].async.batch(strategy: .count(2)) {
            actual.append(batch)
        }

        #expect(actual == expected)
    }

    @Test("An empty upstream finishes with no batches")
    func emptyUpstreamEmitsNothing() async throws {
        let expected: [[Int]] = []

        var actual = [[Int]]()
        for try await batch in [Int]().async.batch(strategy: .count(3)) {
            actual.append(batch)
        }

        #expect(actual == expected)
    }

    @Test("One element short of the count is emitted when the upstream finishes")
    func oneElementIsEmittedOnFinish() async throws {
        let expected: [[Int]] = [[7]]

        var actual = [[Int]]()
        for try await batch in [7].async.batch(strategy: .count(3)) {
            actual.append(batch)
        }

        #expect(actual == expected)
    }

    @Test("count(1) emits every element in an array of its own")
    func countOfOneEmitsEachElementAlone() async throws {
        let expected: [[Int]] = [[1], [2], [3]]

        var actual = [[Int]]()
        for try await batch in [1, 2, 3].async.batch(strategy: .count(1)) {
            actual.append(batch)
        }

        #expect(actual == expected)
    }

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

    // MARK: signal

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

    @Test("either with the smaller of two counts flushes at the smaller")
    func eitherOfTwoCountsFlushesAtTheSmaller() async throws {
        let expected: [[Int]] = [[1, 2], [3, 4], [5]]

        var actual = [[Int]]()
        for try await batch in [1, 2, 3, 4, 5].async.batch(strategy: .either(.count(5), .count(2))) {
            actual.append(batch)
        }

        #expect(actual == expected)
    }

    @Test("either of no strategies emits everything in one array when the upstream finishes")
    func eitherOfNothingCollectsEverything() async throws {
        let expected: [[Int]] = [[1, 2, 3]]

        var actual = [[Int]]()
        for try await batch in [1, 2, 3].async.batch(strategy: .either()) {
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
