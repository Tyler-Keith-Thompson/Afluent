//
//  SingleValueSubjectTests.swift
//
//
//  Created by Tyler Thompson on 11/10/23.
//

import ConcurrencyExtras
import Foundation
import Testing

@testable import Afluent

struct SingleValueSubjectTests {
    @Test func singleValueSubjectEmittingValueBeforeTaskRuns() async throws {
        try await confirmation { confirmation in
            let expected = Int.random(in: 1...1000)
            let subject = SingleValueSubject<Int>()
            let unitOfWork = subject.map {
                confirmation()
                return $0
            }

            try subject.send(expected)

            let actual = try await unitOfWork.execute()
            #expect(actual == expected)
        }
    }

    @Test func singleValueSubjectEmittingValueAfterTaskRuns() async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, any Error>) in
            let expected = Int.random(in: 1...1000)
            let subject = SingleValueSubject<Int>()
            subject.map {
                defer { continuation.resume() }
                #expect($0 == expected)
                return $0
            }.run()  // task started

            do {
                try subject.send(expected)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    @Test func singleValueSubjectEmittingErrorBeforeTaskRuns() async throws {
        enum Err: Error { case e1 }
        let subject = SingleValueSubject<Int>()

        try subject.send(error: Err.e1)

        let actualResult = try await subject.result
        #expect { try actualResult.get() } throws: { error in
            error as? Err == .e1
        }
    }

    @Test func singleValueSubjectEmittingErrorAfterTaskRuns() async throws {
        try await withMainSerialExecutor {
            enum Err: Error { case e1 }
            try await withCheckedThrowingContinuation { continuation in
                Task {
                    let subject = SingleValueSubject<Int>()
                    let unitOfWork =
                        subject
                        .materialize()
                        .map {
                            continuation.resume()
                            return $0
                        }

                    _ = Task {
                        try subject.send(error: Err.e1)
                    }

                    do {
                        let actualResult = try await unitOfWork.execute()
                        #expect { try actualResult.get() } throws: { error in
                            error as? Err == .e1
                        }
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    @Test func singleValueSubjectOnlyEmitsValueOnce() async throws {
        let expected = Int.random(in: 1...1000)
        let subject = SingleValueSubject<Int>()
        subject.map {
            #expect($0 == expected)
            return $0
        }.run()  // task started

        try subject.send(expected)
        #expect(throws: (any Error).self) { try subject.send(expected) }
    }

    @Test func singleValueSubjectOnlyEmitsErrorOnce() async throws {
        try await withMainSerialExecutor {
            enum Err: Error { case e1 }
            let subject = SingleValueSubject<Int>()
            let exp1 = SingleValueSubject<Void>()
            let unitOfWork =
                subject
                .materialize()
                .map {
                    try! exp1.send()
                    return $0
                }

            let exp2 = SingleValueSubject<Void>()
            _ = Task {
                try subject.send(error: Err.e1)
                #expect(throws: (any Error).self) { try subject.send(error: Err.e1) }
                try! exp2.send()
            }

            try await exp2.execute()
            let actualResult = try await unitOfWork.execute()
            try await exp1.execute()
            #expect { try actualResult.get() } throws: { error in
                error as? Err == .e1
            }
        }
    }

    @Test func voidSingleValueSubjectEmittingValueBeforeTaskRuns() async throws {
        let subject = SingleValueSubject<Void>()
        try await confirmation { exp in
            let unitOfWork = subject.map {
                exp()
            }

            try subject.send()

            try await unitOfWork.execute()
        }
    }

    @Test func voidSingleValueSubjectEmittingValueAfterTaskRuns() async throws {
        try await withCheckedThrowingContinuation { continuation in
            let subject = SingleValueSubject<Void>()
            subject.map {
                continuation.resume()
            }.run()  // task started

            do {
                try subject.send()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    @Test func singleValueSubjectEmittingValueConcurrentlyWithExecute() async throws {
        let expected = Int.random(in: 1...1000)
        try await confirmation { exp in
            let subject = SingleValueSubject<Int>()
            let unitOfWork = subject.map {
                exp()
                return $0
            }

            let sendUnitOfWork = DeferredTask {
                try subject.send(expected)
            }

            async let _actual = unitOfWork.execute()
            sendUnitOfWork.run()

            let actual = try await _actual

            #expect(actual == expected)
        }
    }

    @Test func singleValueSubjectEmittingErrorConcurrentlyWithExecute() async throws {
        enum Err: Error { case e1 }
        try await confirmation { exp in
            let subject = SingleValueSubject<Int>()
            let unitOfWork =
                subject
                .materialize()
                .map {
                    exp()
                    return $0
                }

            let sendUnitOfWork = DeferredTask {
                try subject.send(error: Err.e1)
            }

            async let _actual = unitOfWork.execute()
            sendUnitOfWork.run()

            let actual = try await _actual
            #expect { try actual.get() } throws: { error in
                error as? Err == .e1
            }
        }
    }

    @Test func singleValueSubjectCancellation() async throws {
        try await withMainSerialExecutor {
            let subject = SingleValueSubject<Void>()

            let task = Task {
                _ = await #expect(throws: CancellationError.self) {
                    try await subject.execute()
                }
            }

            // make sure we don't cancel before the subject operation has begun
            await Task.megaYield()
            task.cancel()

            await task.value

            // should not throw, even though the subject was cancelled
            try subject.send()
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(
        "A value sent while execute() is starting to wait always reaches the waiter",
        .timeLimit(.minutes(1)))
    func valueSentWhileExecuteStartsToWaitReachesTheWaiter() async throws {
        let iterations = 1_000
        for iteration in 0..<iterations {
            let subject = SingleValueSubject<Int>()
            let waiter = Task.detached { try await subject.execute() }
            let sender = Task.detached { try subject.send(iteration) }
            try await sender.value
            let received = try await waiter.value
            #expect(received == iteration)
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(
        "An error sent while execute() is starting to wait always reaches the waiter",
        .timeLimit(.minutes(1)))
    func errorSentWhileExecuteStartsToWaitReachesTheWaiter() async throws {
        struct Sent: Error, Equatable {}
        let iterations = 1_000
        for _ in 0..<iterations {
            let subject = SingleValueSubject<Int>()
            let waiter = Task.detached { try await subject.execute() }
            let sender = Task.detached { try subject.send(error: Sent()) }
            try await sender.value
            let result = await waiter.result
            #expect(throws: Sent.self) { try result.get() }
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(
        "Cancelling the subject while execute() is starting to wait ends the wait",
        .timeLimit(.minutes(1)))
    func cancelWhileExecuteStartsToWaitEndsTheWait() async throws {
        let iterations = 1_000
        for _ in 0..<iterations {
            let subject = SingleValueSubject<Int>()
            let waiter = Task.detached { try await subject.execute() }
            let canceller = Task.detached { subject.cancel() }
            await canceller.value
            let result = await waiter.result
            #expect(throws: CancellationError.self) { try result.get() }
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test("alreadySent becomes true once a value is sent, and not before")
    func alreadySentReflectsCompletion() throws {
        let subject = SingleValueSubject<Int>()
        let before = subject.alreadySent
        try subject.send(1)
        let after = subject.alreadySent
        #expect(before == false)
        #expect(after == true)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(
        "Every execute() pending before send(_:) returns the value", .timeLimit(.minutes(1)))
    func everyPendingExecuteReturnsTheSentValue() async throws {
        try await withMainSerialExecutor {
            let waiterCount = 8
            let expected = 42
            let subject = SingleValueSubject<Int>()
            let waiters = (0..<waiterCount).map { _ in Task { try await subject.execute() } }
            await Task.megaYield()

            try subject.send(expected)

            var received = [Int]()
            for waiter in waiters { received.append(try await waiter.value) }
            let everyWaiterGotTheValue = Array(repeating: expected, count: waiterCount)
            #expect(received == everyWaiterGotTheValue)
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(
        "Every execute() pending before send(error:) throws the error", .timeLimit(.minutes(1)))
    func everyPendingExecuteThrowsTheSentError() async throws {
        struct Sent: Error {}
        try await withMainSerialExecutor {
            let waiterCount = 8
            let subject = SingleValueSubject<Int>()
            let waiters = (0..<waiterCount).map { _ in Task { try await subject.execute() } }
            await Task.megaYield()

            try subject.send(error: Sent())

            var threwTheSentError = [Bool]()
            for waiter in waiters {
                let result = await waiter.result
                guard case .failure(let error) = result else {
                    threwTheSentError.append(false)
                    continue
                }
                threwTheSentError.append(error is Sent)
            }
            let everyWaiterThrew = Array(repeating: true, count: waiterCount)
            #expect(threwTheSentError == everyWaiterThrew)
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(
        "Every execute() pending before send() on a Void subject returns", .timeLimit(.minutes(1)))
    func everyPendingExecuteReturnsWhenVoidIsSent() async throws {
        try await withMainSerialExecutor {
            let waiterCount = 8
            let subject = SingleValueSubject<Void>()
            let waiters = (0..<waiterCount).map { _ in Task { try await subject.execute() } }
            await Task.megaYield()

            try subject.send()

            var returned = 0
            for waiter in waiters {
                try await waiter.value
                returned += 1
            }
            #expect(returned == waiterCount)
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(
        "Cancelling the subject makes every pending execute() throw CancellationError",
        .timeLimit(.minutes(1)))
    func cancelEndsEveryPendingExecute() async {
        await withMainSerialExecutor {
            let waiterCount = 8
            let subject = SingleValueSubject<Int>()
            let waiters = (0..<waiterCount).map { _ in Task { try await subject.execute() } }
            await Task.megaYield()

            subject.cancel()

            var threwCancellation = [Bool]()
            for waiter in waiters {
                let result = await waiter.result
                guard case .failure(let error) = result else {
                    threwCancellation.append(false)
                    continue
                }
                threwCancellation.append(error is CancellationError)
            }
            let everyWaiterThrew = Array(repeating: true, count: waiterCount)
            #expect(threwCancellation == everyWaiterThrew)
        }
    }
}
