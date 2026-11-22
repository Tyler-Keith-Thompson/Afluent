//
//  SingleValueSubjectWaitCancellationTests.swift
//  Afluent
//

import ConcurrencyExtras
import Foundation
import Testing

@testable import Afluent

// The cancellation tests run on the main serial executor and yield before cancelling, so the cancelled task has
// registered its wait first: the case where only the wait's own cancellation handler can end it.
@Suite(.timeLimit(.minutes(1)))
struct SingleValueSubjectWaitCancellationTests {
    @Test(
        "Cancelling a task iterating toAsyncSequence() ends it with CancellationError, and the subject takes a later send"
    )
    func cancellingToAsyncSequenceIterationLeavesTheSubjectPending() async throws {
        try await withMainSerialExecutor {
            let subject = SingleValueSubject<Int>()
            let expected = 7
            let iterating = Task {
                for try await _ in subject.toAsyncSequence() {}
            }

            await Task.megaYield()
            iterating.cancel()
            let iterated = await iterating.result
            try subject.send(expected)
            let actual = try await subject.execute()
            let actualError: (any Error)? = if case .failure(let error) = iterated { error } else { nil }

            #expect(actualError is CancellationError)
            #expect(actual == expected)
        }
    }

    @Test("Cancelling one of two tasks awaiting operation() resumes only that one; the other gets the sent value")
    func cancellingOneOperationWaiterLeavesTheOtherPending() async throws {
        try await withMainSerialExecutor {
            let subject = SingleValueSubject<Int>()
            let expected = 5
            let cancelled = Task { try await subject.operation() }
            let kept = Task { try await subject.operation() }

            await Task.megaYield()
            cancelled.cancel()
            let cancelledResult = await cancelled.result
            try subject.send(expected)
            let actual = try await kept.value
            let actualError: (any Error)? = if case .failure(let error) = cancelledResult { error } else { nil }

            #expect(actualError is CancellationError)
            #expect(actual == expected)
        }
    }

    @Test("Cancelling a toAsyncSequence() iteration leaves an execute() waiter pending, and it gets the later send")
    func cancellingIterationLeavesExecuteWaitersPending() async throws {
        try await withMainSerialExecutor {
            let subject = SingleValueSubject<Int>()
            let expected = 9
            let executing = Task { try await subject.execute() }
            let iterating = Task {
                for try await _ in subject.toAsyncSequence() {}
            }

            await Task.megaYield()
            iterating.cancel()
            let iterated = await iterating.result
            try subject.send(expected)
            let actual = try await executing.value
            let actualError: (any Error)? = if case .failure(let error) = iterated { error } else { nil }

            #expect(actualError is CancellationError)
            #expect(actual == expected)
        }
    }

    @Test("operation() from an already-cancelled task throws CancellationError and leaves the subject pending")
    func operationFromACancelledTaskThrows() async throws {
        let subject = SingleValueSubject<Int>()
        let expected = 3
        let waiting = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await subject.operation()
        }

        let waited = await waiting.result
        try subject.send(expected)
        let actual = try await subject.execute()

        #expect(throws: CancellationError.self) { try waited.get() }
        #expect(actual == expected)
    }

    @Test("toAsyncSequence() yields the value sent to the subject, then finishes")
    func toAsyncSequenceYieldsTheSentValue() async throws {
        let subject = SingleValueSubject<Int>()
        let expected: [Int] = [5]
        let iterating = Task {
            var values: [Int] = []
            for try await value in subject.toAsyncSequence() { values.append(value) }
            return values
        }

        try subject.send(5)
        let actual = try await iterating.value

        #expect(actual == expected)
    }
}
