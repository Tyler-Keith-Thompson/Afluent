//
//  MaterializeTests.swift
//
//
//  Created by Tyler Thompson on 11/3/23.
//

import Foundation
import Afluent
import XCTest

final class MaterializeTests: XCTestCase {
    func testMaterializeCapturesSuccesses() async throws {
        let result = try await DeferredTask {
            1
        }
        .materialize()
        .execute()
        
        XCTAssertEqual(try result.get(), 1)
    }
    
    func testMaterializeCapturesNonCancelErrors() async throws {
        let result = try await DeferredTask {
            throw URLError(.badURL)
        }
        .materialize()
        .execute()
        
        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(error as? URLError, URLError(.badURL))
        }
    }
    
    func testDematerializeWithError() async throws {
        let result = try await DeferredTask {
            throw URLError(.badURL)
        }
        .materialize()
        .dematerialize()
        .result
        
        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(error as? URLError, URLError(.badURL))
        }
    }
    
    func testDematerializeWithoutError() async throws {
        let result = try await DeferredTask {
            1
        }
        .materialize()
        .dematerialize()
        .execute()
        
        XCTAssertEqual(result, 1)
    }
    
    func testMaterializeDoesNotInterfereWithCancellation() async throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] == "true")
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
        }.materialize()
        
        task.run()

        try await Task.sleep(for: .milliseconds(2))
        
        task.cancel()
        
        await fulfillment(of: [exp], timeout: 0.011)
        
        let started = await test.started
        let ended = await test.ended
        
        XCTAssert(started)
        XCTAssertFalse(ended)
    }
}
