//
//  SingleValueChannelTests.swift
//
//
//  Created by Tyler Thompson on 11/11/23.
//

import Afluent
import ConcurrencyExtras
import Foundation
import Testing

struct SingleValueChannelTests {
    @Test func SingleValueChannelEmittingValueBeforeTaskRuns() async throws {
        try await confirmation { confirmation in
            let expected = Int.random(in: 1 ... 1000)
            let subject = SingleValueChannel<Int>()
            let unitOfWork = subject.map {
                confirmation()
                return $0
            }

            try await subject.send(expected)

            let actual = try await unitOfWork.execute()
            #expect(actual == expected)
        }
    }

    @Test func SingleValueChannelEmittingValueAfterTaskRuns() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let expected = Int.random(in: 1 ... 1000)
            let subject = SingleValueChannel<Int>()
            subject.map {
                defer { continuation.resume() }
                #expect($0 == expected)
                return $0
            }.run() // task started

            Task {
                do {
                    try await subject.send(expected)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @Test func SingleValueChannelEmittingErrorBeforeTaskRuns() async throws {
        enum Err: Error { case e1 }
        let subject = SingleValueChannel<Int>()

        try await subject.send(error: Err.e1)

        let actualResult = try await subject.result
        #expect { try actualResult.get() } throws: { error in
            error as? Err == .e1
        }
    }

    @Test func SingleValueChannelEmittingErrorAfterTaskRuns() async throws {
        try await withMainSerialExecutor {
            enum Err: Error { case e1 }
            try await withCheckedThrowingContinuation { continuation in
                Task {
                    let subject = SingleValueChannel<Int>()
                    let unitOfWork = subject
                        .materialize()
                        .map {
                            continuation.resume()
                            return $0
                        }

                    Task {
                        try await subject.send(error: Err.e1)
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

    @Test func SingleValueChannelOnlyEmitsValueOnce() async throws {
        let expected = Int.random(in: 1 ... 1000)
        let subject = SingleValueChannel<Int>()
        subject.map {
            #expect($0 == expected)
            return $0
        }.run() // task started

        try await subject.send(expected)
        await #expect(throws: (any Error).self) { try await subject.send(expected) }
    }

    @Test func SingleValueChannelOnlyEmitsErrorOnce() async throws {
        enum Err: Error { case e1 }
        try await confirmation { exp in
            try await withMainSerialExecutor {
                let subject = SingleValueChannel<Int>()
                let unitOfWork = subject
                    .materialize()
                    .map {
                        exp()
                        return $0
                    }

                let task = Task {
                    try await subject.send(error: Err.e1)
                    let result = await Task { try await subject.send(error: Err.e1) }.result
                    #expect(throws: (any Error).self) { try result.get() }
                }

                let actualResult = try await unitOfWork.execute()
                _ = await task.result
                #expect { try actualResult.get() } throws: { error in
                    error as? Err == .e1
                }
            }
        }
    }

    @Test func voidSingleValueChannelEmittingValueBeforeTaskRuns() async throws {
        let subject = SingleValueChannel<Void>()
        try await confirmation { exp in
            let unitOfWork = subject.map {
                exp()
            }

            try await subject.send()

            try await unitOfWork.execute()
        }
    }

    @Test func voidSingleValueChannelEmittingValueAfterTaskRuns() async throws {
        try await withCheckedThrowingContinuation { continuation in
            let subject = SingleValueChannel<Void>()
            subject.map {
                continuation.resume()
            }.run() // task started

            Task {
                do {
                    try await subject.send()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @Test func SingleValueChannelEmittingValueConcurrentlyWithExecute() async throws {
        let expected = Int.random(in: 1 ... 1000)
        try await confirmation { exp in
            let subject = SingleValueChannel<Int>()
            let unitOfWork = subject.map {
                exp()
                return $0
            }

            let sendUnitOfWork = DeferredTask {
                try await subject.send(expected)
            }

            async let _actual = unitOfWork.execute()
            sendUnitOfWork.run()

            let actual = try await _actual

            #expect(actual == expected)
        }
    }

    @Test func SingleValueChannelEmittingErrorConcurrentlyWithExecute() async throws {
        enum Err: Error { case e1 }
        try await confirmation { exp in
            let subject = SingleValueChannel<Int>()
            let unitOfWork = subject
                .materialize()
                .map {
                    exp()
                    return $0
                }

            let sendUnitOfWork = DeferredTask {
                try await subject.send(error: Err.e1)
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
