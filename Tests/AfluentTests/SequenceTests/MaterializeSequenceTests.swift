//
//  MaterializeSequenceTests.swift
//
//
//  Created by Tyler Thompson on 12/1/23.
//

import Afluent
import ConcurrencyExtras
import Foundation
import Testing

struct MaterializeSequenceTests {
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func materializeCapturesSuccesses() async throws {
        let result = try await DeferredTask { 1 }
            .toAsyncSequence()
            .materialize()
            .first()

        if case .element(let val) = result {
            #expect(val == 1)
        } else {
            Issue.record("Expected element, got: \(String(describing: result))")
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func materializeCapturesCompletion() async throws {
        let result = try await DeferredTask { 1 }
            .toAsyncSequence()
            .materialize()
            .dropFirst()
            .first()

        guard case .complete = result else {
            Issue.record("Expected completion, got: \(String(describing: result))")
            return
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func materializeCapturesNonCancelErrors() async throws {
        let result = try await DeferredTask { throw GeneralError.e1 }
            .toAsyncSequence()
            .materialize()
            .first()

        if case .failure(let error) = result {
            #expect(error as? GeneralError == GeneralError.e1)
        } else {
            Issue.record("Expected failure, got: \(String(describing: result))")
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func dematerializeWithError() async throws {
        let result = await Task {
            try await DeferredTask { throw GeneralError.e1 }
                .toAsyncSequence()
                .materialize()
                .dematerialize()
                .first()
        }.result

        #expect { try result.get() } throws: { error in
            error as? GeneralError == GeneralError.e1
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func dematerializeWithoutError() async throws {
        let result = try await DeferredTask { 1 }
            .toAsyncSequence()
            .materialize()
            .dematerialize()
            .first()

        #expect(result == 1)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func materializeDoesNotInterfereWithCancellation() async throws {
        await withMainSerialExecutor {
            actor Test {
                var started = false
                var ended = false
                var task: Task<Void, Error>?

                func start() { started = true }
                func end() { ended = true }
                func setTask(_ task: Task<Void, Error>?) {
                    self.task = task
                }
            }
            let test = Test()

            await withCheckedContinuation { continuation in
                Task {
                    await test.setTask(
                        Task {
                            _ = try await DeferredTask {
                                await test.start()
                                await test.task?.cancel()
                            }
                            .handleEvents(receiveCancel: {
                                continuation.resume()
                            })
                            .map {
                                await test.end()
                            }
                            .toAsyncSequence()
                            .materialize()
                            .first()
                        })
                }
            }

            let started = await test.started
            let ended = await test.ended

            #expect(started)
            #expect(!ended)
        }
    }
}
