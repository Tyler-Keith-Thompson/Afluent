//
//  HandleEventsSequenceTests.swift
//
//
//  Created by Tyler Thompson on 12/1/23.
//

import Afluent
import ConcurrencyExtras
import Foundation
import XCTest

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
final class HandleEventsSequenceTests: XCTestCase {
    func testHandleMakeIterator() async throws {
        actor Test {
            var iteratorMade = false

            func makeIterator() { iteratorMade = true }
        }
        let test = Test()

        _ = await Task {
            var subtask: Task<Void, Never>?
            _ = DeferredTask { }
                .toAsyncSequence()
                .handleEvents(receiveMakeIterator: {
                    subtask = Task {
                        await test.makeIterator()
                    }
                })
                .makeAsyncIterator()
            _ = await subtask?.result
        }.value

        let iteratorMade = await test.iteratorMade

        XCTAssert(iteratorMade)
    }

    func testHandleNext() async throws {
        actor Test {
            var nextCalled: Int = 0

            func next() { nextCalled += 1 }
        }
        let test = Test()

        let values = Array(0 ... 9)

        let task = Task {
            let sequence = values.async.handleEvents(receiveNext: {
                await test.next()
            })

            for try await _ in sequence { }
        }

        try await task.value

        let nextCalled = await test.nextCalled

        XCTAssertEqual(nextCalled, values.count + 1) // values + finish
    }

    func testHandleOutput() async throws {
        actor Test {
            var output: Any?

            func output(_ any: Any?) { output = any }
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

        XCTAssertEqual(output as? Int, 1)
    }

    func testHandleComplete() async throws {
        let exp = expectation(description: "thing happened")
        Task {
            let sequence = DeferredTask { 1 }
                .toAsyncSequence()
                .handleEvents(receiveComplete: {
                    exp.fulfill()
                })
            for try await _ in sequence { }
        }

        await fulfillment(of: [exp], timeout: 1)
    }

    func testHandleError() async throws {
        actor Test {
            var error: Error?

            func error(_ error: Error) { self.error = error }
        }
        let test = Test()

        let exp = expectation(description: "thing happened")
        Task {
            try await DeferredTask {
                throw URLError(.badURL)
            }
            .toAsyncSequence()
            .handleEvents(receiveError: {
                await test.error($0)
                exp.fulfill()
            })
            .first()
        }

        await fulfillment(of: [exp], timeout: 1)

        let error = await test.error

        XCTAssertEqual(error as? URLError, URLError(.badURL))
    }

    func testHandleCancel() async throws {
        await withMainSerialExecutor { [self] in
            actor Test {
                var canceled = false

                func cancel() { canceled = true }
            }
            let test = Test()

            let exp = expectation(description: "thing happened")
            var task: AnyCancellable?
            task = DeferredTask {
                task?.cancel()
            }
            .toAsyncSequence()
            .handleEvents(receiveCancel: {
                await test.cancel()
                exp.fulfill()
            })
            .sink()

            await fulfillment(of: [exp], timeout: 1)

            let canceled = await test.canceled

            XCTAssert(canceled)
        }
    }
}

extension Array {
    fileprivate var async: AsyncStream<Element> {
        AsyncStream { continuation in
            for element in self {
                continuation.yield(element)
            }
            continuation.finish()
        }
    }
}
