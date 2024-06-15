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
        final class Test: @unchecked Sendable {
            let lock = NSRecursiveLock()

            var _val = ""
            var val: String {
                get {
                    lock.lock()
                    defer { lock.unlock() }
                    return _val
                } set {
                    lock.lock()
                    defer { lock.unlock() }
                    _val = newValue
                }
            }
        }

        let test = Test()

        try await DeferredTask { "test" }
            .assign(to: \.val, on: test)

        #expect(test.val == "test")
    }
}
