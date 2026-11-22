//
//  CustomBatchStrategyTests.swift
//  Afluent
//

// A plain import, as a caller's module has: custom strategies need nothing internal.
import Afluent
import AfluentTesting
import Atomics
import Foundation
import Testing

@Suite(.timeLimit(.minutes(1)))
struct CustomBatchStrategyTests {
    /// Flushes after each element that matches a predicate, as a caller would write it.
    struct FlushAfterMatch<Value: Sendable>: BatchStrategy {
        let matches: @Sendable (Value) -> Bool

        func flushes<Element>(pending: [Element]) -> Bool {
            guard let last = pending.last as? Value else { return false }
            return matches(last)
        }
    }

    /// Flushes every time a stream it was given produces a value, from its own task.
    struct FlushOnTicks: BatchStrategy {
        let ticks: AsyncStream<Void>

        func run(_ flusher: BatchFlusher) async throws {
            for await _ in ticks {
                flusher.flush()
            }
        }
    }

    @Test("A custom strategy flushes after each element its predicate matches")
    func customPredicateFlushes() async throws {
        let strategy = FlushAfterMatch<Int> { $0 == 0 }
        let expected: [[Int]] = [[1, 2, 0], [0], [3, 4]]

        var actual = [[Int]]()
        for try await batch in [1, 2, 0, 0, 3, 4].async.batch(strategy: strategy) {
            actual.append(batch)
        }

        #expect(actual == expected)
    }

    @Test("A custom strategy composes with a built-in one in either, and each flush restarts the count")
    func customStrategyComposesInEither() async throws {
        let expected: [[Int]] = [[1, 0], [2, 3, 4], [0], [5]]

        var actual = [[Int]]()
        let sut = [1, 0, 2, 3, 4, 0, 5].async
            .batch(strategy: .either(FlushAfterMatch<Int> { $0 == 0 }, .count(3)))
        for try await batch in sut {
            actual.append(batch)
        }

        #expect(actual == expected)
    }

    @Test("A custom strategy's run(_:) flushes through the flusher")
    func customRunFlushes() async throws {
        let (ticks, tick) = AsyncStream<Void>.makeStream()
        let (upstream, continuation) = AsyncStream<Int>.makeStream()
        let requests = ManagedAtomic(0)
        let batches = ManagedAtomic(0)
        let expected: [[Int]] = [[1, 2], [3]]
        let task = Task {
            var received = [[Int]]()
            let sut = upstream
                .handleEvents(receiveNext: { requests.wrappingIncrement(ordering: .sequentiallyConsistent) })
                .batch(strategy: .either(FlushOnTicks(ticks: ticks), .count(10)))
            for try await batch in sut {
                received.append(batch)
                batches.wrappingIncrement(ordering: .sequentiallyConsistent)
            }
            return received
        }

        continuation.yield(1)
        continuation.yield(2)
        try await wait(until: requests.load(ordering: .sequentiallyConsistent) == 3, timeout: .seconds(2))
        tick.yield()
        try await wait(until: batches.load(ordering: .sequentiallyConsistent) == 1, timeout: .seconds(2))
        continuation.yield(3)
        continuation.finish()
        let actual = try await task.value
        tick.finish()

        #expect(actual == expected)
    }
}
