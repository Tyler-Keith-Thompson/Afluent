//
//  JustSequenceTests.swift
//
//
//  Created by Tyler Thompson on 12/24/23.
//

import Afluent
import Atomics
import Foundation
import XCTest

final class JustSequenceTests: XCTestCase {
    func testJustSequenceOnlyEmitsOneValue() async throws {
        let counter = ManagedAtomic(0)

        for try await val in Just(1) {
            counter.wrappingIncrement(ordering: .relaxed)
            XCTAssertEqual(val, 1)
        }

        XCTAssertEqual(counter.load(ordering: .relaxed), 1)
    }
}
