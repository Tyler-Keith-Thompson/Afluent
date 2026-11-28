//
//  BatchStrategyArgumentTests.swift
//  Afluent
//

// @testable for BatchFlusher's initializer, to run a strategy on its own.
@testable import Afluent
import Atomics
import Foundation
import Testing

@Suite(.timeLimit(.minutes(1)))
struct BatchStrategyArgumentTests {
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("count(0) makes the first next() throw NonPositiveCount before the upstream is read")
    func countOfZeroThrowsBeforeReadingTheUpstream() async throws {
        let reads = ManagedAtomic(0)
        let expectedReads: Int = 0
        let upstream = [1, 2, 3].async.handleEvents(receiveOutput: { _ in
            reads.wrappingIncrement(ordering: .relaxed)
        })
        var sut = upstream.batch(strategy: .count(0)).makeAsyncIterator()

        await #expect(throws: CountBatchStrategy<Int>.NonPositiveCount()) { try await sut.next() }

        #expect(reads.load(ordering: .relaxed) == expectedReads)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("After throwing NonPositiveCount, the batched sequence's next() returns nil")
    func nextReturnsNilAfterNonPositiveCount() async throws {
        let expected: [Int]? = nil
        var sut = [1, 2, 3].async.batch(strategy: .count(0)).makeAsyncIterator()
        await #expect(throws: CountBatchStrategy<Int>.NonPositiveCount()) { try await sut.next() }

        let actual = try await sut.next()

        #expect(actual == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("A negative count makes the batched sequence throw NonPositiveCount")
    func negativeCountThrows() async throws {
        let sut = [1, 2, 3].async.batch(strategy: CountBatchStrategy(-1))

        await #expect(throws: CountBatchStrategy<Int>.NonPositiveCount()) {
            for try await _ in sut {}
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("count(1), the smallest count, emits each element alone")
    func countOfOneEmitsEachElementAlone() async throws {
        let expected: [[Int]] = [[1], [2], [3]]

        var actual = [[Int]]()
        for try await batch in [1, 2, 3].async.batch(strategy: .count(1)) {
            actual.append(batch)
        }

        #expect(actual == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("time(interval:) with an interval of zero makes the batched sequence throw NonPositiveInterval")
    func zeroIntervalThrows() async throws {
        let sut = [1, 2, 3].async.batch(
            strategy: .time(interval: .zero, clock: ContinuousClock()))

        await #expect(throws: TimeBatchStrategy<Int, ContinuousClock>.NonPositiveInterval()) {
            for try await _ in sut {}
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("time(interval:) with a negative interval makes the batched sequence throw NonPositiveInterval")
    func negativeIntervalThrows() async throws {
        let sut = [1, 2, 3].async.batch(
            strategy: .time(interval: .seconds(-1), clock: ContinuousClock()))

        await #expect(throws: TimeBatchStrategy<Int, ContinuousClock>.NonPositiveInterval()) {
            for try await _ in sut {}
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("A TimeBatchStrategy with an interval of zero throws NonPositiveInterval from run(_:) too")
    func zeroIntervalThrowsFromRunOnItsOwn() async throws {
        let flushes = ManagedAtomic(0)
        let expectedFlushes: Int = 0
        let flusher = BatchFlusher(
            flushIfDue: { _ in flushes.wrappingIncrement(ordering: .relaxed) },
            observeFlushes: { _ in })
        let sut = TimeBatchStrategy<Int, ContinuousClock>(interval: .zero, clock: ContinuousClock())

        await #expect(throws: TimeBatchStrategy<Int, ContinuousClock>.NonPositiveInterval()) {
            try await sut.run(flusher)
        }

        #expect(flushes.load(ordering: .relaxed) == expectedFlushes)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("A count of zero inside either(_:_:) makes the batched sequence throw NonPositiveCount")
    func countOfZeroInsideEitherThrows() async throws {
        let sut = [1, 2, 3].async.batch(
            strategy: .either(
                .time(interval: .seconds(1), clock: ContinuousClock()),
                .count(0)))

        await #expect(throws: CountBatchStrategy<Int>.NonPositiveCount()) {
            for try await _ in sut {}
        }
    }
}
