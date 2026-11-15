//
//  TimeoutSequenceTests.swift
//  Afluent
//

import Afluent
import AfluentTesting
import Atomics
import Clocks
import ConcurrencyExtras
import Foundation
import Testing

struct TimeoutSequenceTests {
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1))) func timeoutPassesEveryElementThroughWhenTheUpstreamFinishesInTime() async throws {
        let clock = TrackedTestClock()
        let expected: [Int] = [1, 2, 3]

        var received = [Int]()
        for try await element in [1, 2, 3].async.timeout(.milliseconds(10), clock: clock) {
            received.append(element)
        }

        #expect(received == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1))) func timeoutOverAnEmptyUpstreamFinishesWithNoElements() async throws {
        let clock = TrackedTestClock()
        let expected: [Int] = []

        var received = [Int]()
        for try await element in [Int]().async.timeout(.milliseconds(10), clock: clock) {
            received.append(element)
        }

        #expect(received == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1))) func timeoutOverOneElementPassesItThrough() async throws {
        let clock = TrackedTestClock()
        let expected: [Int] = [7]

        var received = [Int]()
        for try await element in [7].async.timeout(.milliseconds(10), clock: clock) {
            received.append(element)
        }

        #expect(received == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1))) func timeoutOnTheDefaultClockPassesElementsThrough() async throws {
        let expected: [Int] = [1, 2, 3]

        var received = [Int]()
        for try await element in [1, 2, 3].async.timeout(.seconds(60)) {
            received.append(element)
        }

        #expect(received == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1))) func timeoutThrowsTimeoutErrorWhenNoFirstElementArrivesInTime() async throws {
        let clock = TrackedTestClock()
        let (stream, continuation) = AsyncStream<Int>.makeStream()
        defer { continuation.finish() }

        let task = Task {
            var received = [Int]()
            for try await element in stream.timeout(.milliseconds(10), clock: clock) {
                received.append(element)
            }
            return received
        }

        try await clock.advance(by: .milliseconds(10), whenSleeping: 1)

        let result = await task.result
        #expect(throws: TimeoutError.timedOut) { try result.get() }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1))) func timeoutDoesNotFireBeforeTheDurationPasses() async throws {
        let clock = TrackedTestClock()
        let (stream, continuation) = AsyncStream<Int>.makeStream()
        let expected: [Int] = [1]

        let task = Task {
            var received = [Int]()
            for try await element in stream.timeout(.milliseconds(10), clock: clock) {
                received.append(element)
            }
            return received
        }

        // One tick short of the deadline: the timer stays asleep.
        try await clock.advance(by: .milliseconds(9), whenSleeping: 1)
        continuation.yield(1)
        continuation.finish()

        let received = try await task.value
        #expect(received == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1))) func everyElementRestartsTheTimer() async throws {
        let clock = TrackedTestClock()
        let (stream, continuation) = AsyncStream<Int>.makeStream()
        let receivedCount = ManagedAtomic(0)
        let expected: [Int] = [1, 2]

        let task = Task {
            var received = [Int]()
            for try await element in stream.timeout(.milliseconds(10), clock: clock) {
                received.append(element)
                receivedCount.wrappingIncrement(ordering: .sequentiallyConsistent)
            }
            return received
        }

        try await clock.advance(by: .milliseconds(6), whenSleeping: 1)
        continuation.yield(1)
        try await wait(
            until: receivedCount.load(ordering: .sequentiallyConsistent) == 1,
            timeout: .seconds(2))
        // 12 ms in: past the first deadline, but only 6 ms after the first element.
        try await clock.advance(by: .milliseconds(6), whenSleeping: 1)
        continuation.yield(2)
        try await wait(
            until: receivedCount.load(ordering: .sequentiallyConsistent) == 2,
            timeout: .seconds(2))
        try await clock.advance(by: .milliseconds(6), whenSleeping: 1)
        continuation.finish()

        let received = try await task.value
        #expect(received == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1))) func timeoutThrowsAfterTheElementsThatArrivedBeforeTheGap() async throws {
        let clock = TrackedTestClock()
        let (stream, continuation) = AsyncStream<Int>.makeStream()
        defer { continuation.finish() }
        let received = LockIsolated([Int]())
        let expected: [Int] = [1, 2]

        let task = Task {
            for try await element in stream.timeout(.milliseconds(10), clock: clock) {
                received.withValue { $0.append(element) }
            }
        }

        continuation.yield(1)
        continuation.yield(2)
        try await wait(until: received.value.count == 2, timeout: .seconds(2))
        try await clock.advance(by: .milliseconds(10), whenSleeping: 1)

        let result = await task.result
        #expect(throws: TimeoutError.timedOut) { try result.get() }
        #expect(received.value == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1))) func timeoutReportsTheDurationItWaited() async throws {
        let clock = TrackedTestClock()
        let (stream, continuation) = AsyncStream<Int>.makeStream()
        defer { continuation.finish() }
        let expected = "Timed out after waiting \(Duration.milliseconds(10))"

        let task = Task {
            for try await _ in stream.timeout(.milliseconds(10), clock: clock) {}
        }

        try await clock.advance(by: .milliseconds(10), whenSleeping: 1)

        let result = await task.result
        #expect { try result.get() } throws: { error in
            error.localizedDescription == expected
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1))) func timeoutThrowsTheCustomErrorWhenOneIsGiven() async throws {
        struct Quiet: Error, Equatable {}
        let clock = TrackedTestClock()
        let (stream, continuation) = AsyncStream<Int>.makeStream()
        defer { continuation.finish() }

        let task = Task {
            for try await _ in stream.timeout(.milliseconds(10), clock: clock, customError: Quiet())
            {}
        }

        try await clock.advance(by: .milliseconds(10), whenSleeping: 1)

        let result = await task.result
        #expect(throws: Quiet()) { try result.get() }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1))) func timeoutPassesTheUpstreamsErrorThrough() async throws {
        struct Broken: Error, Equatable {}
        let clock = TrackedTestClock()
        let (stream, continuation) = AsyncThrowingStream<Int, any Error>.makeStream()
        let expected: [Int] = [1]
        let received = LockIsolated([Int]())

        let task = Task {
            for try await element in stream.timeout(.milliseconds(10), clock: clock) {
                received.withValue { $0.append(element) }
            }
        }

        continuation.yield(1)
        continuation.finish(throwing: Broken())

        let result = await task.result
        #expect(throws: Broken()) { try result.get() }
        #expect(received.value == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1))) func firingTheTimerCancelsTheUpstream() async throws {
        let clock = TrackedTestClock()
        let upstreamCancelled = ManagedAtomic(false)
        let (upstream, continuation) = AsyncStream<Int>.makeStream()
        defer { continuation.finish() }
        continuation.onTermination = { termination in
            if case .cancelled = termination {
                upstreamCancelled.store(true, ordering: .sequentiallyConsistent)
            }
        }

        let task = Task {
            for try await _ in upstream.timeout(.milliseconds(10), clock: clock) {}
        }

        try await clock.advance(by: .milliseconds(10), whenSleeping: 1)
        _ = await task.result

        try await wait(
            until: upstreamCancelled.load(ordering: .sequentiallyConsistent),
            timeout: .seconds(2))
        let cancelled = upstreamCancelled.load(ordering: .sequentiallyConsistent)
        #expect(cancelled)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1))) func timeoutThrowsWithoutWaitingForAnUpstreamThatIgnoresCancellation() async throws {
        /// A sequence whose `next()` suspends on a continuation with no cancellation handler.
        struct Stubborn: AsyncSequence, Sendable {
            let waiting: LockIsolated<CheckedContinuation<Int?, Never>?>
            struct AsyncIterator: AsyncIteratorProtocol {
                let waiting: LockIsolated<CheckedContinuation<Int?, Never>?>
                func next() async -> Int? {
                    await withCheckedContinuation { continuation in
                        waiting.setValue(continuation)
                    }
                }
            }
            func makeAsyncIterator() -> AsyncIterator { AsyncIterator(waiting: waiting) }
        }
        let clock = TrackedTestClock()
        let waiting = LockIsolated<CheckedContinuation<Int?, Never>?>(nil)

        let task = Task {
            for try await _ in Stubborn(waiting: waiting).timeout(.milliseconds(10), clock: clock) {}
        }

        try await wait(until: waiting.value != nil, timeout: .seconds(2))
        try await clock.advance(by: .milliseconds(10), whenSleeping: 1)

        let result = await task.result
        #expect(throws: TimeoutError.timedOut) { try result.get() }
        waiting.value?.resume(returning: nil)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1))) func aZeroDurationThrowsBeforeTheFirstElement() async throws {
        let clock = TrackedTestClock()
        let received = LockIsolated([Int]())
        let expected: [Int] = []

        func iterate() async throws {
            for try await element in [1, 2, 3].async.timeout(.zero, clock: clock) {
                received.withValue { $0.append(element) }
            }
        }

        await #expect(throws: TimeoutError.timedOut) { try await iterate() }
        #expect(received.value == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1))) func breakingOutOfTheLoopCancelsTheUpstreamAndTheTimer() async throws {
        let clock = TrackedTestClock()
        let upstreamCancelled = ManagedAtomic(false)
        let (upstream, continuation) = AsyncStream<Int>.makeStream()
        defer { continuation.finish() }
        continuation.onTermination = { termination in
            if case .cancelled = termination {
                upstreamCancelled.store(true, ordering: .sequentiallyConsistent)
            }
        }
        let expected: [Int] = [1]
        continuation.yield(1)

        var received = [Int]()
        for try await element in upstream.timeout(.milliseconds(10), clock: clock) {
            received.append(element)
            break
        }

        try await wait(
            until: upstreamCancelled.load(ordering: .sequentiallyConsistent)
                && clock.sleepingCount == 0,
            timeout: .seconds(2))
        #expect(received == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1))) func cancellingTheConsumerCancelsTheUpstreamAndTheTimer() async throws {
        let clock = TrackedTestClock()
        let upstreamCancelled = ManagedAtomic(false)
        let (upstream, continuation) = AsyncStream<Int>.makeStream()
        defer { continuation.finish() }
        continuation.onTermination = { termination in
            if case .cancelled = termination {
                upstreamCancelled.store(true, ordering: .sequentiallyConsistent)
            }
        }

        let task = Task {
            for try await _ in upstream.timeout(.milliseconds(10), clock: clock) {}
        }

        try await wait(until: clock.sleepingCount == 1, timeout: .seconds(2))
        task.cancel()
        _ = await task.result

        try await wait(
            until: upstreamCancelled.load(ordering: .sequentiallyConsistent)
                && clock.sleepingCount == 0,
            timeout: .seconds(2))
        #expect(clock.sleepingCount == 0)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1))) func anElementAfterTheDeadlineThrowsEvenWhenTheTimerWakesLate() async throws {
        /// A clock whose time moves only when the test says, and whose sleeps never wake.
        struct StalledClock: Clock {
            typealias Duration = Swift.Duration
            typealias Instant = TestClock<Duration>.Instant
            let current = LockIsolated(Instant())
            var now: Instant { current.value }
            var minimumResolution: Duration { .zero }
            func sleep(until deadline: Instant, tolerance: Duration?) async throws {
                // Never sent: this waits until the sleeping task is cancelled.
                try await SingleValueSubject<Void>().execute()
            }
        }
        let clock = StalledClock()
        let (stream, continuation) = AsyncStream<Int>.makeStream()
        defer { continuation.finish() }
        let received = LockIsolated([Int]())
        let expected: [Int] = [1]

        let task = Task {
            for try await element in stream.timeout(.milliseconds(10), clock: clock) {
                received.withValue { $0.append(element) }
            }
        }

        continuation.yield(1)
        try await wait(until: received.value.count == 1, timeout: .seconds(2))
        clock.current.withValue { $0 = $0.advanced(by: .milliseconds(10)) }
        continuation.yield(2)

        let result = await task.result
        #expect(throws: TimeoutError.timedOut) { try result.get() }
        #expect(received.value == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1))) func cancellationBetweenElementsThrowsAndCancelsTheUpstreamAndTheTimer() async throws {
        let clock = TrackedTestClock()
        let upstreamCancelled = ManagedAtomic(false)
        let (upstream, continuation) = AsyncStream<Int>.makeStream()
        defer { continuation.finish() }
        continuation.onTermination = { termination in
            if case .cancelled = termination {
                upstreamCancelled.store(true, ordering: .sequentiallyConsistent)
            }
        }
        continuation.yield(1)
        let sequence = upstream.timeout(.milliseconds(10), clock: clock)

        let task = Task { () -> (Int?, (any Error)?) in
            var iterator = sequence.makeAsyncIterator()
            let first = try await iterator.next()
            withUnsafeCurrentTask { $0?.cancel() }
            do {
                _ = try await iterator.next()
                return (first, nil)
            } catch {
                return (first, error)
            }
        }

        let (first, error) = try await task.value
        try await wait(
            until: upstreamCancelled.load(ordering: .sequentiallyConsistent)
                && clock.sleepingCount == 0,
            timeout: .seconds(2))
        let expectedFirst: Int? = 1
        #expect(first == expectedFirst)
        #expect(error is CancellationError)
    }
}
