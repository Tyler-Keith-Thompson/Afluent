//
//  AssignTests.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Afluent
import Foundation
import Testing

struct AssignTests {
    @Test func assignToProperty() async throws {
        class Test {
            var val = ""
        }

        let test = Test()

        try await DeferredTask { "test" }
            .assign(to: \.val, on: test)

        #expect(test.val == "test")
    }
}
