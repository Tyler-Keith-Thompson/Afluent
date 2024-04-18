//
//  FlatMapSequenceTests.swift
//
//
//  Created by Tyler Thompson on 3/17/24.
//

import Afluent
import ConcurrencyExtras
import Foundation
import Testing

struct FlatMapSequenceTests {
    @Test func flatMapUnlimitedSequence() async throws {
        let (seq1, cont1) = AsyncThrowingStream<Int, Error>.makeStream()
        cont1.yield(1)
        let (seq2, cont2) = AsyncThrowingStream<Int, Error>.makeStream()

        let results = try await AsyncThrowingStream {
            $0.yield(seq1)
            $0.yield(seq2)
            $0.finish()
        }
        .handleEvents(receiveComplete: {
            cont1.finish()
            cont2.finish()
        })
        .flatMap(maxSubscriptions: .unlimited) { $0 }
        .collect()
        .first()

        try #expect(Set(#require(results)) == [1])
    }

    @Test func flatMapCorrectlyCancels() async throws {
        await withMainSerialExecutor {
            let (seq1, cont1) = AsyncThrowingStream<Int, Error>.makeStream()
            cont1.yield(1)
            let (seq2, _) = AsyncThrowingStream<Int, Error>.makeStream()

            let cancellableTask = Task {
                try await AsyncThrowingStream { continuation in
                    DeferredTask { continuation }
                        .delay(for: .milliseconds(1))
                        .map {
                            continuation.yield(seq1)
                            $0.yield(seq2)
                            $0.finish()
                        }
                        .run()
                }
                .flatMap(maxSubscriptions: .unlimited) { $0 }
                .first()
            }

            cancellableTask.cancel()

            let result = await cancellableTask.result

            #expect(throws: CancellationError.self) { try result.get() }
        }
    }
}
