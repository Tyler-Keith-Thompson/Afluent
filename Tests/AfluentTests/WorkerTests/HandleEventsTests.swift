//
//  HandleEventsTests.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Afluent
import ConcurrencyExtras
import Foundation
import XCTest

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
final class HandleEventsTests: XCTestCase {
    func testHandleOperation() async throws {
        actor Test {
            var operationCalled = false

            func operation() { operationCalled = true }
        }
        let test = Test()

        let exp = expectation(description: "thing happened")
        DeferredTask { }
            .handleEvents(receiveOperation: {
                await test.operation()
                exp.fulfill()
            })
            .run()

        await fulfillment(of: [exp], timeout: 1)

        let operationCalled = await test.operationCalled

        XCTAssert(operationCalled)
    }

    func testHandleOutput() async throws {
        actor Test {
            var output: Any?

            func output(_ any: Any?) { output = any }
        }
        let test = Test()

        let exp = expectation(description: "thing happened")
        DeferredTask {
            1
        }.handleEvents(receiveOutput: {
            await test.output($0)
            exp.fulfill()
        }).run()

        await fulfillment(of: [exp], timeout: 1)

        let output = await test.output

        XCTAssertEqual(output as? Int, 1)
    }

    func testHandleError() async throws {
        actor Test {
            var error: Error?

            func error(_ error: Error) { self.error = error }
        }
        let test = Test()

        let exp = expectation(description: "thing happened")
        DeferredTask {
            throw URLError(.badURL)
        }.handleEvents(receiveError: {
            await test.error($0)
            exp.fulfill()
        }).run()

        await fulfillment(of: [exp], timeout: 1)

        let error = await test.error

        XCTAssertEqual(error as? URLError, URLError(.badURL))
    }

    func testHandleCancel() async throws {
        await withMainSerialExecutor {
            actor Test {
                var canceled = false

                func cancel() { canceled = true }
            }
            let test = Test()

            let exp = expectation(description: "thing happened")
            var task: AnyCancellable?
            task = DeferredTask { task?.cancel() }
                .handleEvents(receiveCancel: {
                    await test.cancel()
                    exp.fulfill()
                })
                .subscribe()

            await fulfillment(of: [exp], timeout: 0.1)

            let canceled = await test.canceled

            XCTAssert(canceled)
        }
    }
}
