//
//  AnyAsyncSequenceTests.swift
//
//
//  Created by Tyler Thompson on 11/28/23.
//

import Afluent
import Foundation
import Testing

struct AnyAsyncSequenceTests {
    @Test func erasureOfAsyncSequence() async throws {
        let val = try await DeferredTask { true }.toAsyncSequence()
            .flatMap { branch -> AnyAsyncSequence<Int> in
                if branch {
                    return DeferredTask { 1 }.toAsyncSequence().eraseToAnyAsyncSequence()
                } else {
                    return DeferredTask { 0 }.toAsyncSequence().eraseToAnyAsyncSequence()
                }
            }.first()

        #expect(val == 1)
    }

    @Test func erasureOfAsyncSequence_OtherBranch() async throws {
        let val = try await DeferredTask { false }.toAsyncSequence()
            .flatMap { branch -> AnyAsyncSequence<Int> in
                if branch {
                    return DeferredTask { 1 }.toAsyncSequence().eraseToAnyAsyncSequence()
                } else {
                    return DeferredTask { 0 }.toAsyncSequence().eraseToAnyAsyncSequence()
                }
            }.first()

        #expect(val == 0)
    }

    @Test(.timeLimit(.minutes(1))) func anErasedSequenceYieldsEveryElementInOrderThenFinishes() async throws {
        let erased = AsyncStream<Int> { continuation in
            for element in 1 ... 5 { continuation.yield(element) }
            continuation.finish()
        }.eraseToAnyAsyncSequence()
        let expected = [1, 2, 3, 4, 5]

        var actual = [Int]()
        for try await element in erased { actual.append(element) }

        #expect(actual == expected)
    }

    @Test(.timeLimit(.minutes(1))) func anErasedEmptySequenceFinishesAtOnce() async throws {
        let erased = AsyncStream<Int> { continuation in continuation.finish() }.eraseToAnyAsyncSequence()
        var iterator = erased.makeAsyncIterator()

        let actual = try await iterator.next()

        #expect(actual == nil)
    }

    @Test(.timeLimit(.minutes(1))) func anErasedSequenceThrowsTheUpstreamsError() async throws {
        struct Expected: Error, Equatable {}
        let erased = AsyncThrowingStream<Int, any Error> { continuation in
            continuation.yield(1)
            continuation.finish(throwing: Expected())
        }.eraseToAnyAsyncSequence()
        var iterator = erased.makeAsyncIterator()
        let expectedFirst = 1

        let first = try await iterator.next()
        await #expect(throws: Expected()) { try await iterator.next() }

        #expect(first == expectedFirst)
    }

    @Test(.timeLimit(.minutes(1))) func eachIteratorOfAnErasedSequenceStartsFromTheBeginning() async throws {
        /// A sequence any number of iterators can walk, each from the start.
        struct Counting: AsyncSequence, Sendable {
            struct AsyncIterator: AsyncIteratorProtocol {
                var current = 1
                mutating func next() async -> Int? {
                    guard current <= 3 else { return nil }
                    defer { current += 1 }
                    return current
                }
            }
            func makeAsyncIterator() -> AsyncIterator { AsyncIterator() }
        }
        let erased = Counting().eraseToAnyAsyncSequence()
        var first = erased.makeAsyncIterator()
        var second = erased.makeAsyncIterator()
        let expected: [Int?] = [1, 1, 2, 2]

        let actual = [
            try await first.next(), try await second.next(), try await first.next(), try await second.next(),
        ]

        #expect(actual == expected)
    }

    @Test(.timeLimit(.minutes(1))) func copiesOfAnErasedIteratorShareItsPosition() async throws {
        let erased = AsyncStream<Int> { continuation in
            for element in 1 ... 3 { continuation.yield(element) }
            continuation.finish()
        }.eraseToAnyAsyncSequence()
        var original = erased.makeAsyncIterator()
        var copy = original
        let expected: [Int?] = [1, 2, 3, nil]

        let actual = [try await original.next(), try await copy.next(), try await original.next(), try await copy.next()]

        #expect(actual == expected)
    }
}
