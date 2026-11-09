//
//  DeferredSequenceTests.swift
//
//
//  Created by Annalise Mariottini on 12/20/23.
//

import Afluent
import Atomics
import ConcurrencyExtras
import Foundation
import Testing

struct DeferredTests {
    @Test(
        .disabled("There's some kind of Xcode 16 bug where this crashes intermittently"))
    func upstreamSequenceDefersExecutionUntilIteration() async throws {
        let started = ManagedAtomic<Bool>(false)
        let sent = Array(0...9)

        let sequence = Deferred {
            defer {
                started.store(true, ordering: .sequentiallyConsistent)
            }
            return AsyncStream(Int.self) { continuation in
                sent.forEach { continuation.yield($0) }
                continuation.finish()
            }
        }

        var iterator = sequence.makeAsyncIterator()

        let exp = started.load(ordering: .sequentiallyConsistent)
        #expect(!exp)

        var received = try [await iterator.next()]

        let val = started.load(ordering: .sequentiallyConsistent)
        #expect(val)

        while let i = try await iterator.next() {
            received.append(i)
        }

        #expect(received == sent)
    }

    @Test func returnsANewIteratorEachTime() async throws {
        let sent = Array(0...9)

        let sequence = Deferred {
            AsyncStream(Int.self) { continuation in
                sent.forEach { continuation.yield($0) }
                continuation.finish()
            }
        }

        @Sendable func iterate() async throws {
            var received: [Int] = []
            for try await i in sequence {
                received.append(i)
            }
            #expect(received == sent)
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0...9 {
                group.addTask {
                    try await iterate()
                }
            }

            for try await _ in group {}
        }
    }

    @Test func canRetryUpstreamSequence() async throws {
        enum Err: Error {
            case e1
        }

        actor Test {
            var upstreamCount = 0

            func increment() {
                upstreamCount += 1
            }
        }

        let test = Test()
        let sequence = Deferred {
            AsyncThrowingStream(Int.self) { continuation in
                Task {
                    guard await test.upstreamCount > 0 else {
                        continuation.yield(with: .failure(Err.e1))
                        await test.increment()
                        return
                    }
                    await test.increment()
                    continuation.finish()
                }
            }
        }

        for try await _ in sequence.retry() {}

        #expect(await test.upstreamCount == 2)
    }

    @Test func checksForCancellation() async throws {
        await withMainSerialExecutor {
            let sequence = Deferred<AsyncStream<Int>> { AsyncStream { _ in } }

            let task = Task {
                for try await _ in sequence {}
            }
            task.cancel()

            let result: Result<Void, Error> = await {
                do {
                    return try .success(await task.value)
                } catch {
                    return .failure(error)
                }
            }()

            #expect(throws: CancellationError.self) { try result.get() }
        }
    }

    @Test(
        "Deferred emits every element of an upstream whose iterator is a value type, then finishes",
        .timeLimit(.minutes(1)))
    func deferredIteratesAValueTypeUpstreamToItsEnd() async throws {
        // A struct iterator: an operator that advances a copy of it repeats the first element.
        struct Count: AsyncSequence, Sendable {
            let end: Int
            struct AsyncIterator: AsyncIteratorProtocol {
                var next = 0
                let end: Int
                mutating func next() async -> Int? {
                    guard next < end else { return nil }
                    defer { next += 1 }
                    return next
                }
            }
            func makeAsyncIterator() -> AsyncIterator { AsyncIterator(end: end) }
        }
        let sequence = Deferred { Count(end: 3) }
        var received = [Int]()
        // Bounded, so a repeating upstream fails rather than hangs.
        for try await element in sequence {
            received.append(element)
            if received.count > 10 { break }
        }
        let expected = [0, 1, 2]
        #expect(received == expected)
    }
}
