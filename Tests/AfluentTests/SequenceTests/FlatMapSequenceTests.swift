//
//  FlatMapSequenceTests.swift
//
//
//  Created by Tyler Thompson on 3/17/24.
//

import Afluent
import Clocks
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

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test func flatMapCorrectlyCancels() async throws {
        let (seq1, cont1) = AsyncThrowingStream<Int, Error>.makeStream()
        cont1.yield(1)
        let (seq2, _) = AsyncThrowingStream<Int, Error>.makeStream()

        // A clock that never advances: the inner sequences only arrive after the cancellation, never before.
        let clock = TestClock()
        let cancellableTask = Task {
            try await AsyncThrowingStream { continuation in
                let producer = Task {
                    try await DeferredTask { continuation }
                        .delay(for: .milliseconds(1), clock: clock)
                        .map {
                            continuation.yield(seq1)
                            $0.yield(seq2)
                            $0.finish()
                        }
                        .execute()
                }
                // The clock never advances, so stop the producer when the stream ends rather than leave it asleep.
                continuation.onTermination = { _ in producer.cancel() }
            }
            .flatMap(maxSubscriptions: .unlimited) { $0 }
            .first()
        }

        cancellableTask.cancel()

        let result = await cancellableTask.result

        #expect(throws: CancellationError.self) { try result.get() }
    }
}
