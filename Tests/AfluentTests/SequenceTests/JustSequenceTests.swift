//
//  JustSequenceTests.swift
//
//
//  Created by Tyler Thompson on 12/24/23.
//

import Afluent
import Atomics
import Foundation
import Testing

struct JustSequenceTests {
    func testJustSequenceOnlyEmitsOneValue() async throws {
        let counter = ManagedAtomic(0)

        for try await val in Just(1) {
            counter.wrappingIncrement(ordering: .relaxed)
            #expect(val == 1)
        }

        #expect(counter.load(ordering: .relaxed) == 1)
    }
}
