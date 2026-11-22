//
//  SubjectSubscriptionTests.swift
//  Afluent
//

import ConcurrencyExtras
import Foundation
import PropertyBased
import Testing

@testable import Afluent

@Suite(.timeLimit(.minutes(1)))
struct SubjectSubscriptionTests {
    @Test("Cancelling a pending wait throws CancellationError, and the next wait receives every value sent after it")
    func cancellingAPendingWaitKeepsTheSubscription() async throws {
        // The main serial executor and the yield let the wait register before it is cancelled.
        try await withMainSerialExecutor {
            let subject = PassthroughSubject<Int>()
            let sut = subject.makeSubscription()
            let waiting = Task { try await sut.next() }
            await Task.megaYield()
            waiting.cancel()
            let waited = await waiting.result
            let actualError: (any Error)? = if case .failure(let error) = waited { error } else { nil }
            let expected: [Int?] = [1, 2]

            subject.send(1)
            subject.send(2)
            let actual: [Int?] = [try await sut.next(), try await sut.next()]

            #expect(actualError is CancellationError)
            #expect(actual == expected)
        }
    }

    @Test("A cancelled wait takes nothing from the buffer, so values sent before and after it arrive in order")
    func cancelledWaitKeepsBufferedValues() async throws {
        let subject = PassthroughSubject<Int>()
        let sut = subject.makeSubscription()
        subject.send(1)
        let waiting = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await sut.next()
        }
        let waited = await waiting.result
        let expected: [Int?] = [1, 2]

        subject.send(2)
        let actual: [Int?] = [try await sut.next(), try await sut.next()]

        #expect(throws: CancellationError.self) { try waited.get() }
        #expect(actual == expected)
    }

    @Test("Releasing a subscription unsubscribes it, so later sends don't buffer for it")
    func releasingTheSubscriptionUnsubscribes() async throws {
        let subject = PassthroughSubject<Int>()
        var sut: SubjectSubscription<Int>? = subject.makeSubscription()
        weak let subscription = sut?.subscription

        sut = nil
        subject.send(1)

        #expect(subscription == nil)
    }

    @Test("Cancelling a task waiting in the subject's iterator still ends that iterator and drops its subscription")
    func iteratorCancellationStillEndsTheSubscription() async throws {
        // The main serial executor and the yield let the wait register before it is cancelled.
        try await withMainSerialExecutor {
            let subject = PassthroughSubject<Int>()
            let iterator = subject.makeAsyncIterator()
            let waiting = Task {
                var iterator = iterator
                return try await iterator.next()
            }
            await Task.megaYield()
            waiting.cancel()
            let waited = try await waiting.value

            subject.send(5)
            var after = iterator
            let actual = try await after.next()

            #expect(waited == nil)
            #expect(actual == nil)
        }
    }

    @Test("A CurrentValueSubject's subscription starts with the current value, then the values sent after it")
    func currentValueSubscriptionStartsWithTheCurrentValue() async throws {
        let subject = CurrentValueSubject(0)
        let sut = subject.makeSubscription()
        let expected: [Int?] = [0, 1]

        subject.send(1)
        let actual: [Int?] = [try await sut.next(), try await sut.next()]

        #expect(actual == expected)
    }

    @Test("A subscription returns its buffered values, then nil once the subject has finished")
    func finishedSubjectEndsAfterTheBuffer() async throws {
        let subject = PassthroughSubject<Int>()
        let sut = subject.makeSubscription()
        let expected: [Int?] = [1, nil, nil]

        subject.send(1)
        subject.send(completion: .finished)
        let actual: [Int?] = [try await sut.next(), try await sut.next(), try await sut.next()]

        #expect(actual == expected)
    }

    @Test("A subscription returns its buffered values, then throws the error the subject finished with")
    func failedSubjectThrowsAfterTheBuffer() async throws {
        struct Expected: Error {}
        let subject = PassthroughSubject<Int>()
        let sut = subject.makeSubscription()
        let expected = 1

        subject.send(1)
        subject.send(completion: .failure(Expected()))
        let actual = try await sut.next()

        #expect(actual == expected)
        await #expect(throws: Expected.self) { try await sut.next() }
    }

    @Test("A subscription made after the subject finished returns nil at once")
    func subscriptionAfterFinishReturnsNil() async throws {
        let subject = PassthroughSubject<Int>()
        subject.send(completion: .finished)
        let sut = subject.makeSubscription()

        let actual = try await sut.next()

        #expect(actual == nil)
    }

    @Test("The documentation's example keeps the events sent after a cancelled round")
    func documentationExample() async throws {
        let events = PassthroughSubject<String>()
        let subscription = events.makeSubscription()

        let firstRound = Task { try await subscription.next() }
        firstRound.cancel()  // Throws CancellationError from that wait; nothing is lost.
        _ = await firstRound.result

        events.send("launch")
        events.send("login")
        let first = try await subscription.next()  // "launch"
        let second = try await subscription.next()  // "login"

        #expect(first == "launch")
        #expect(second == "login")
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("A batch run over a subscription that is cancelled leaves the subscription for the next run")
    func cancelledBatchRunLeavesTheSubscription() async throws {
        // The main serial executor and the yield let the first run reach its wait before it is cancelled.
        try await withMainSerialExecutor {
            let subject = PassthroughSubject<Int>()
            let subscription = subject.makeSubscription()
            let firstRun = Task {
                for try await _ in AsyncIteratorSequence(subscription).batch(strategy: .count(2)) {}
            }
            await Task.megaYield()
            firstRun.cancel()
            _ = await firstRun.result
            let expected: [[Int]] = [[1, 2], [3]]

            subject.send(1)
            subject.send(2)
            subject.send(3)
            subject.send(completion: .finished)
            var actual: [[Int]] = []
            for try await batch in AsyncIteratorSequence(subscription).batch(strategy: .count(2)) {
                actual.append(batch)
            }

            #expect(actual == expected)
        }
    }

    @Test("A subscription with cancelled waits between the sends returns every value sent, in order")
    func cancelledWaitsLoseNothing() async throws {
        await propertyCheck(
            count: 200, input: Gen.int(in: -1000...1000).array(of: 0...64), Gen.bool.array(of: 64)
        ) { elements, cancelsBefore in
            let subject = PassthroughSubject<Int>()
            let sut = subject.makeSubscription()
            let expected = elements

            for (index, element) in elements.enumerated() {
                if cancelsBefore[index] {
                    _ = await Task {
                        withUnsafeCurrentTask { $0?.cancel() }
                        return try await sut.next()
                    }.result
                }
                subject.send(element)
            }
            subject.send(completion: .finished)
            var actual: [Int] = []
            while let element = try await sut.next() { actual.append(element) }

            #expect(actual == expected)
        }
    }
}
