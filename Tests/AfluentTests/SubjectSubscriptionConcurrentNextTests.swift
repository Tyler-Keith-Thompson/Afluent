//
//  SubjectSubscriptionConcurrentNextTests.swift
//  Afluent
//

import ConcurrencyExtras
import Foundation
import Testing

@testable import Afluent

@Suite(.timeLimit(.minutes(1)))
struct SubjectSubscriptionConcurrentNextTests {
    @Test("A second next() while another is waiting throws ConcurrentNext rather than trapping")
    func aSecondWaitThrowsConcurrentNext() async {
        // The main serial executor and the yield let the first wait register before the second call.
        await withMainSerialExecutor {
            let subject = PassthroughSubject<Int>()
            let sut = subject.makeSubscription()
            let waiting = Task { try await sut.next() }
            await Task.megaYield()

            var actual: (any Error)?
            do { _ = try await sut.next() } catch { actual = error }

            #expect(actual is SubjectSubscription<Int>.ConcurrentNext)
            waiting.cancel()
            _ = await waiting.result
        }
    }

    @Test("After a second next() is turned away, a send reaches the call that was waiting")
    func theWaitingCallStillReceivesTheNextValue() async throws {
        try await withMainSerialExecutor {
            let subject = PassthroughSubject<Int>()
            let sut = subject.makeSubscription()
            let waiting = Task { try await sut.next() }
            await Task.megaYield()
            _ = try? await sut.next()
            let expected: Int? = 1

            subject.send(1)
            let actual = try await waiting.value

            #expect(actual == expected)
        }
    }

    @Test("After a second next() is turned away, cancelling the waiting call throws CancellationError and keeps every value")
    func cancellingTheWaitingCallAfterwardsKeepsThePlace() async throws {
        try await withMainSerialExecutor {
            let subject = PassthroughSubject<Int>()
            let sut = subject.makeSubscription()
            let waiting = Task { try await sut.next() }
            await Task.megaYield()
            _ = try? await sut.next()
            let expected: [Int?] = [1, 2]

            waiting.cancel()
            let waited = await waiting.result
            subject.send(1)
            subject.send(2)
            let actual: [Int?] = [try await sut.next(), try await sut.next()]

            #expect(throws: CancellationError.self) { try waited.get() }
            #expect(actual == expected)
        }
    }

    @Test("A cancelled task's second next() throws CancellationError and leaves the waiting call to receive the next value")
    func aCancelledSecondCallDoesNotCancelTheWaitingOne() async throws {
        try await withMainSerialExecutor {
            let subject = PassthroughSubject<Int>()
            let sut = subject.makeSubscription()
            let waiting = Task { try await sut.next() }
            await Task.megaYield()
            let expected: Int? = 1

            let second = await Task {
                withUnsafeCurrentTask { $0?.cancel() }
                return try await sut.next()
            }.result
            subject.send(1)
            let actual = try await waiting.value

            #expect(throws: CancellationError.self) { try second.get() }
            #expect(actual == expected)
        }
    }

    @Test("Calls one after another never throw ConcurrentNext")
    func sequentialCallsAreNotConcurrent() async throws {
        let subject = PassthroughSubject<Int>()
        let sut = subject.makeSubscription()
        subject.send(1)
        subject.send(2)
        subject.send(completion: .finished)
        let expected: [Int?] = [1, 2, nil]

        let actual: [Int?] = [try await sut.next(), try await sut.next(), try await sut.next()]

        #expect(actual == expected)
    }
}
