//
//  CancelTests.swift
//  
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation
import Afluent
import XCTest

final class CancelTests: XCTestCase {
    func testDeferredTaskCancelledBeforeItStarts() throws {
        let exp = self.expectation(description: "thing happened")
        exp.isInverted = true
        let task = DeferredTask { exp.fulfill() }
        task.cancel()
        XCTAssertThrowsError(try task.run())

        self.wait(for: [exp], timeout: 0.001)
    }
    
    func testDeferredTaskCancelledBeforeItEnds() async throws {
        actor Test {
            var started = false
            var ended = false
            
            func start() { started = true }
            func end() { ended = true }
        }
        let test = Test()
        
        let exp = self.expectation(description: "thing happened")
        exp.isInverted = true
        let task = DeferredTask {
            await test.start()
            try await Task.sleep(for: .milliseconds(10))
        }.map {
            await test.end()
            exp.fulfill()
        }
        
        try task.run()

        try await Task.sleep(for: .milliseconds(2))
        
        task.cancel()
        
        await fulfillment(of: [exp], timeout: 1)
        
        let started = await test.started
        let ended = await test.ended
        
        XCTAssert(started)
        XCTAssertFalse(ended)
    }
}
