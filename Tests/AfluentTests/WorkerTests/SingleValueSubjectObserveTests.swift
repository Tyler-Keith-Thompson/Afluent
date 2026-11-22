//
//  SingleValueSubjectObserveTests.swift
//  Afluent
//

import Foundation
import Testing

@testable import Afluent

@Suite(.timeLimit(.minutes(1)))
struct SingleValueSubjectObserveTests {
    @Test("Cancelling an observer leaves an execute() waiter pending, and it gets the later send")
    func cancellingAnObserverLeavesExecuteWaitersPending() async throws {
        let subject = SingleValueSubject<Int>()
        let expected = 7
        let executing = Task { try await subject.execute() }
        let observing = Task { try await subject.observe() }

        observing.cancel()
        let observed = await observing.result
        try subject.send(expected)
        let actual = try await executing.value

        #expect(throws: CancellationError.self) { try observed.get() }
        #expect(actual == expected)
    }

    @Test("observe() from an already-cancelled task throws CancellationError and leaves the subject pending")
    func observeFromACancelledTaskThrows() async throws {
        let subject = SingleValueSubject<Int>()
        let expected = 3
        let observing = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await subject.observe()
        }

        let observed = await observing.result
        try subject.send(expected)
        let actual = try await subject.execute()

        #expect(throws: CancellationError.self) { try observed.get() }
        #expect(actual == expected)
    }

    @Test("observe() returns the value sent to the subject")
    func observeReturnsTheSentValue() async throws {
        let subject = SingleValueSubject<Int>()
        let expected = 5
        let observing = Task { try await subject.observe() }

        try subject.send(expected)
        let actual = try await observing.value

        #expect(actual == expected)
    }
}
