//
//  HandleEventsSequenceTests.swift
//
//
//  Created by Tyler Thompson on 12/1/23.
//

import Afluent
import Atomics
import ConcurrencyExtras
import Foundation
import Testing

struct HandleEventsSequenceTests {
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func handleMakeIterator() async throws {
        let iteratorMade = ManagedAtomic(false)

        _ = await Task {
            _ = DeferredTask {}
                .toAsyncSequence()
                .handleEvents(receiveMakeIterator: {
                    iteratorMade.store(true, ordering: .sequentiallyConsistent)
                })
                .makeAsyncIterator()
        }.value

        let actual = iteratorMade.load(ordering: .sequentiallyConsistent)
        #expect(actual)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func handleNext() async throws {
        actor Test {
            var nextCalled: Int = 0

            func next() { nextCalled += 1 }
        }
        let test = Test()

        let values = Array(0...9)

        let task = Task {
            let sequence = values.async.handleEvents(receiveNext: {
                await test.next()
            })

            for try await _ in sequence {}
        }

        try await task.value

        let nextCalled = await test.nextCalled

        #expect(nextCalled == values.count + 1)  // values + finish
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func handleOutput() async throws {
        actor Test {
            var output: Int?

            func output(_ any: Int?) { output = any }
        }
        let test = Test()

        let task = Task {
            try await DeferredTask {
                1
            }
            .toAsyncSequence()
            .handleEvents(receiveOutput: {
                await test.output($0)
            })
            .first()
        }

        _ = try await task.value

        let output = await test.output

        #expect(output == 1)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func handleComplete() async throws {
        await confirmation { exp in
            _ = await Task {
                let sequence = DeferredTask { 1 }
                    .toAsyncSequence()
                    .handleEvents(receiveComplete: {
                        exp()
                    })
                for try await _ in sequence {}
            }.result
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func handleError() async throws {
        actor Test {
            var error: Error?

            func error(_ error: Error) { self.error = error }
        }
        let test = Test()

        await confirmation { exp in
            _ = try? await Task {
                try await DeferredTask {
                    throw GeneralError.e1
                }
                .toAsyncSequence()
                .handleEvents(receiveError: {
                    await test.error($0)
                    exp()
                })
                .first()
            }.value
        }

        let error = await test.error

        #expect(error as? GeneralError == GeneralError.e1)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func handleCancel() async throws {
        await withMainSerialExecutor {
            actor Test {
                var canceled = false
                var task: AnyCancellable?

                func cancel() { canceled = true }
                func setTask(_ task: AnyCancellable?) {
                    self.task = task
                }
            }
            let test = Test()

            await withCheckedContinuation { continuation in
                Task {
                    await test.setTask(
                        DeferredTask {
                            await test.task?.cancel()
                        }
                        .toAsyncSequence()
                        .handleEvents(receiveCancel: {
                            await test.cancel()
                            continuation.resume()
                        })
                        .sink())
                }
            }

            let canceled = await test.canceled

            #expect(canceled)
        }
    }
}
