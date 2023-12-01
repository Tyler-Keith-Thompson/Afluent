//
//  HandleEventsSequenceTests.swift
//
//
//  Created by Tyler Thompson on 12/1/23.
//

import Foundation
import Afluent
import XCTest

final class HandleEventsSequenceTests: XCTestCase {
    func testHandleOutput() async throws {
        actor Test {
            var output: Any?
            
            func output(_ any: Any?) { output = any }
        }
        let test = Test()
        
        let exp = self.expectation(description: "thing happened")
        let task = Task {
            try await DeferredTask {
                1
            }
            .toAsyncSequence()
            .handleEvents(receiveOutput: {
                await test.output($0)
                exp.fulfill()
            })
            .first()
        }
        
        try await Task.sleep(for: .milliseconds(2))
        
        task.cancel()
        
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
        
        let exp = self.expectation(description: "thing happened")
        let task = Task {
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
        
        try await Task.sleep(for: .milliseconds(2))
        
        task.cancel()
        
        await fulfillment(of: [exp], timeout: 1)
        
        let error = await test.error
        
        XCTAssertEqual(error as? URLError, URLError(.badURL))
    }
    
    func testHandleCancel() async throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] == "true")
        actor Test {
            var canceled = false
            
            func cancel() { canceled = true }
        }
        let test = Test()
        
        let exp = self.expectation(description: "thing happened")
        let task = Task {
            try await DeferredTask {
                try await Task.sleep(for: .milliseconds(10))
            }
            .toAsyncSequence()
            .handleEvents(receiveCancel: {
                await test.cancel()
                exp.fulfill()
            })
            .first()
        }
        
        try await Task.sleep(for: .milliseconds(2))
        
        task.cancel()
        
        await fulfillment(of: [exp], timeout: 1)
        
        let canceled = await test.canceled
        
        XCTAssert(canceled)
    }
}
