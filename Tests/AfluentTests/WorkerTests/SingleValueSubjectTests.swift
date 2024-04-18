//
//  SingleValueSubjectTests.swift
//
//
//  Created by Tyler Thompson on 11/10/23.
//

import Afluent
import ConcurrencyExtras
import Foundation
import Testing

struct SingleValueSubjectTests {
    @Test func singleValueSubjectEmittingValueBeforeTaskRuns() async throws {
        try await confirmation { confirmation in
            let expected = Int.random(in: 1 ... 1000)
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

    @Test(.timeLimit(.milliseconds(10))) func singleValueSubjectEmittingValueAfterTaskRuns() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let expected = Int.random(in: 1 ... 1000)
            let subject = SingleValueSubject<Int>()
            subject.map {
                defer { continuation.resume() }
                #expect($0 == expected)
                return $0
            }.run() // task started

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

    @Test(.timeLimit(.milliseconds(10))) func singleValueSubjectEmittingErrorAfterTaskRuns() async throws {
        try await withMainSerialExecutor {
            enum Err: Error { case e1 }
            try await withCheckedThrowingContinuation { continuation in
                Task {
                    let subject = SingleValueSubject<Int>()
                    let unitOfWork = subject
                        .materialize()
                        .map {
                            continuation.resume()
                            return $0
                        }

                    Task {
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
        let expected = Int.random(in: 1 ... 1000)
        let subject = SingleValueSubject<Int>()
        subject.map {
            #expect($0 == expected)
            return $0
        }.run() // task started

        try subject.send(expected)
        #expect(throws: (any Error).self) { try subject.send(expected) }
    }

    @Test func singleValueSubjectOnlyEmitsErrorOnce() async throws {
        try await withMainSerialExecutor {
            enum Err: Error { case e1 }
            try await confirmation { exp in
                let subject = SingleValueSubject<Int>()
                let unitOfWork = subject
                    .materialize()
                    .map {
                        exp()
                        return $0
                    }

                _ = await confirmation { exp1 in
                    Task {
                        try subject.send(error: Err.e1)
                        #expect(throws: (any Error).self) { try subject.send(error: Err.e1) }
                        exp1()
                    }
                }

                let actualResult = try await unitOfWork.execute()
                #expect { try actualResult.get() } throws: { error in
                    error as? Err == .e1
                }
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

    @Test(.timeLimit(.milliseconds(10))) func voidSingleValueSubjectEmittingValueAfterTaskRuns() async throws {
        try await withCheckedThrowingContinuation { continuation in
            let subject = SingleValueSubject<Void>()
            subject.map {
                continuation.resume()
            }.run() // task started

            do {
                try subject.send()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    @Test func singleValueSubjectEmittingValueConcurrentlyWithExecute() async throws {
        let expected = Int.random(in: 1 ... 1000)
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
            let unitOfWork = subject
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
}
