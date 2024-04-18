//
//  HandleEventsTests.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Afluent
import ConcurrencyExtras
import Foundation
import Testing

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct HandleEventsTests {
    @Test func handleOperation() async throws {
        actor Test {
            var operationCalled = false

            func operation() { operationCalled = true }
        }
        let test = Test()

        try await confirmation { exp in
            try await DeferredTask { }
                .handleEvents(receiveOperation: {
                    await test.operation()
                    exp()
                })
                .execute()

            let operationCalled = await test.operationCalled

            #expect(operationCalled)
        }
    }

    @Test func handleOutput() async throws {
        actor Test {
            var output: Any?

            func output(_ any: Any?) { output = any }
        }
        let test = Test()

        try await confirmation { exp in
            try await DeferredTask {
                1
            }.handleEvents(receiveOutput: {
                await test.output($0)
                exp()
            }).execute()

            let output = await test.output

            #expect(output as? Int == 1)
        }
    }

    @Test func handleError() async throws {
        actor Test {
            var error: Error?

            func error(_ error: Error) { self.error = error }
        }
        let test = Test()

        try await confirmation { exp in
            try await DeferredTask {
                throw URLError(.badURL)
            }.handleEvents(receiveError: {
                await test.error($0)
                exp()
            }).replaceError(with: ()).execute()

            let error = await test.error

            #expect(error as? URLError == URLError(.badURL))
        }
    }

    @Test(.timeLimit(.milliseconds(10))) func handleCancel() async throws {
        await withMainSerialExecutor {
            actor Test {
                var canceled = false

                func cancel() { canceled = true }
            }
            let test = Test()

            await withCheckedContinuation { continuation in
                var task: AnyCancellable?
                task = DeferredTask { task?.cancel() }
                    .handleEvents(receiveCancel: {
                        await test.cancel()
                        continuation.resume()
                    })
                    .subscribe()
            }

            let canceled = await test.canceled

            #expect(canceled)
        }
    }
}
