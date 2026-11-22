//
//  AsyncIteratorSequenceTests.swift
//  Afluent
//

import ConcurrencyExtras
import Foundation
import PropertyBased
import Testing

@testable import Afluent

@Suite(.timeLimit(.minutes(1)))
struct AsyncIteratorSequenceTests {
    @Test("An AsyncIteratorSequence yields the wrapped iterator's elements, then finishes")
    func yieldsTheWrappedIteratorsElements() async throws {
        let sut = AsyncIteratorSequence([1, 2, 3].async.makeAsyncIterator())
        let expected: [Int] = [1, 2, 3]

        var actual: [Int] = []
        for try await element in sut { actual.append(element) }

        #expect(actual == expected)
    }

    @Test("An AsyncIteratorSequence over an iterator of an empty sequence finishes at once")
    func emptyIteratorFinishes() async throws {
        let sut = AsyncIteratorSequence(AsyncStream<Int> { $0.finish() }.makeAsyncIterator())
        let expected: [Int] = []

        var actual: [Int] = []
        for try await element in sut { actual.append(element) }

        #expect(actual == expected)
    }

    @Test("An AsyncIteratorSequence over a value-type iterator starts every iteration from where it was wrapped")
    func valueTypeIteratorRestartsEachIteration() async throws {
        let sut = AsyncIteratorSequence(Just(1).makeAsyncIterator())
        let expected: [Int] = [1, 1]

        var actual: [Int] = []
        for try await element in sut { actual.append(element) }
        for try await element in sut { actual.append(element) }

        #expect(actual == expected)
    }

    @Test("An AsyncIteratorSequence rethrows the wrapped iterator's error")
    func rethrowsTheWrappedIteratorsError() async throws {
        struct Expected: Error {}
        let sut = AsyncIteratorSequence(Fail<Int>(error: Expected()).makeAsyncIterator())

        await #expect(throws: Expected.self) {
            for try await _ in sut {}
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(
        "Values sent on a PassthroughSubject right after setting up a batch over its wrapped iterator all reach the consumer"
    )
    func batchOverAWrappedSubjectIteratorReceivesEarlySends() async throws {
        let subject = PassthroughSubject<Int>()
        let batches = AsyncIteratorSequence(subject.makeAsyncIterator()).batch(strategy: .count(2))
        let consumer = Task {
            var received: [[Int]] = []
            for try await batch in batches { received.append(batch) }
            return received
        }
        let expected: [[Int]] = [[1, 2], [3]]

        subject.send(1)
        subject.send(2)
        subject.send(3)
        subject.send(completion: .finished)
        let actual = try await consumer.value

        #expect(actual == expected)
    }

    @Test("Releasing an AsyncIteratorSequence over a subject's iterator that was never iterated unsubscribes it")
    func releasingAnUnusedSubscriptionUnsubscribes() async throws {
        let subject = PassthroughSubject<Int>()
        var sut: AsyncIteratorSequence<PassthroughSubject<Int>.Iterator>? = AsyncIteratorSequence(
            subject.makeAsyncIterator())
        weak let subscription = sut?.base.subscription

        sut = nil
        subject.send(1)

        #expect(subscription == nil)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("Cancelling a batch consumer of a wrapped subject iterator unsubscribes it, so later sends don't reach it")
    func cancellingTheConsumerUnsubscribes() async throws {
        // The main serial executor and the yield let the consumer reach its wait for the subject's next value
        // before it is cancelled.
        try await withMainSerialExecutor {
            let subject = PassthroughSubject<Int>()
            let batches = AsyncIteratorSequence(subject.makeAsyncIterator()).batch(strategy: .count(2))
            let consumer = Task {
                for try await _ in batches {}
            }
            await Task.megaYield()
            consumer.cancel()
            _ = await consumer.result
            let expected: [[Int]] = []

            subject.send(4)
            subject.send(completion: .finished)
            var actual: [[Int]] = []
            for try await batch in batches { actual.append(batch) }

            #expect(actual == expected)
        }
    }

    @Test(
        "An AsyncIteratorSequence over a subject iterator made before the sends yields every value sent, in order",
        .timeLimit(.minutes(1)))
    func subjectSubscriptionYieldsEverySend() async throws {
        await propertyCheck(count: 200, input: Gen.int(in: -1000...1000).array(of: 0...64)) { elements in
            let subject = PassthroughSubject<Int>()
            let sut = AsyncIteratorSequence(subject.makeAsyncIterator())
            let expected = elements

            for element in elements { subject.send(element) }
            subject.send(completion: .finished)
            var actual: [Int] = []
            for try await element in sut { actual.append(element) }

            #expect(actual == expected)
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("The documentation's example batches the events sent before its consumer starts")
    func documentationExample() async throws {
        let events = PassthroughSubject<String>()
        // Subscribes now: every value sent from here on is buffered for the batches below.
        let batches = AsyncIteratorSequence(events.makeAsyncIterator())
            .batch(strategy: .count(2))
        events.send("launch")
        events.send("login")
        events.send(completion: .finished)
        let expected: [[String]] = [["launch", "login"]]

        let consumer = Task {
            var printed: [[String]] = []
            for try await batch in batches {
                printed.append(batch)
            }
            return printed
        }
        let actual = try await consumer.value

        #expect(actual == expected)
    }
}
