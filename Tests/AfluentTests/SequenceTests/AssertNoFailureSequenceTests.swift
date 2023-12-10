//
//  AssertNoFailureSequenceTests.swift
//
//
//  Created by Tyler Thompson on 12/10/23.
//

import Foundation
import Afluent
import XCTest
import CwlPreconditionTesting

final class AssertNoFailureSequenceTests: XCTestCase {
    func testAssertNoFailureThrowsFatalErrorWhenThereIsAFailure() throws {
        throw XCTSkip("Sadly, CwlPreconditionTesting does not support concurrency yet, who knew?")
        XCTAssertThrowsFatalError {
            let exp = self.expectation(description: "thing happened")
            Task {
                try await DeferredTask {
                    throw URLError(.badURL)
                }
                .toAsyncSequence()
                .assertNoFailure()
                .map { _ in exp.fulfill() }
                .first()
            }

            self.wait(for: [exp], timeout: 0.01)
        }
    }
    
    func testAssertNoFailureDoesNotThrowIfThereIsNoFailure() async throws {
        let exp = self.expectation(description: "thing happened")
        try await DeferredTask {
            1
        }
        .toAsyncSequence()
        .assertNoFailure()
        .map { _ in exp.fulfill() }
        .first()
        
        await fulfillment(of: [exp], timeout: 0.01)
    }
}
