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
    @Test func upstreamSequenceDefersExecutionUntilIteration() async throws {
        let started = ManagedAtomic<Bool>(false)
        let sent = Array(0 ... 9)

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

        #expect(!started.load(ordering: .sequentiallyConsistent))

        var received = try [await iterator.next()]

        let val = started.load(ordering: .sequentiallyConsistent)
        #expect(val)

        while let i = try await iterator.next() {
            received.append(i)
        }

        #expect(received == sent)
    }

    @Test func returnsANewIteratorEachTime() async throws {
        let sent = Array(0 ... 9)

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
            for _ in 0 ... 9 {
                group.addTask {
                    try await iterate()
                }
            }

            for try await _ in group { }
        }
    }

    @Test func canRetryUpstreamSequence() async throws {
        enum Err: Error {
            case e1
        }

        var upstreamCount = 0
        let sequence = Deferred {
            AsyncThrowingStream(Int.self) { continuation in
                defer { upstreamCount += 1 }
                guard upstreamCount > 0 else {
                    continuation.yield(with: .failure(Err.e1))
                    return
                }
                continuation.finish()
            }
        }

        for try await _ in sequence.retry() { }

        #expect(upstreamCount == 2)
    }

    @Test func checksForCancellation() async throws {
        await withMainSerialExecutor {
            let sequence = Deferred<AsyncStream<Int>> { AsyncStream { _ in } }

            let task = Task {
                for try await _ in sequence { }
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
}
