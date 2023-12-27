//
//  AssertNoFailureTests.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Afluent
import CwlPreconditionTesting
import Foundation
import XCTest

final class AssertNoFailureTests: XCTestCase {
    func testAssertNoFailureThrowsFatalErrorWhenThereIsAFailure() throws {
        try XCTSkipUnless(false, "Sadly, CwlPreconditionTesting does not support concurrency yet, who knew?")
        XCTAssertThrowsFatalError {
            let exp = self.expectation(description: "thing happened")
            DeferredTask {
                throw URLError(.badURL)
            }
            .assertNoFailure()
            .map { _ in exp.fulfill() }
            .run()

            self.wait(for: [exp], timeout: 0.01)
        }
    }

    func testAssertNoFailureDoesNotThrowIfThereIsNoFailure() throws {
        let exp = expectation(description: "thing happened")
        DeferredTask {
            1
        }
        .assertNoFailure()
        .map { _ in exp.fulfill() }
        .run()

        wait(for: [exp], timeout: 0.01)
    }
}

func XCTAssertThrowsFatalError(instructions: @escaping () -> Void, file: StaticString = #file, line: UInt = #line) {
    #if os(macOS) || os(iOS)
        var reached = false
        let exception = catchBadInstruction {
            instructions()
            reached = true
        }
        XCTAssertNotNil(exception, "No fatal error thrown", file: file, line: line)
        XCTAssertFalse(reached, "Code executed past expected fatal error", file: file, line: line)
    #endif
}
