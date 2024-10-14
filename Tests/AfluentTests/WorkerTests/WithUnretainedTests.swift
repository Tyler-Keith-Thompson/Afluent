//
//  WithUnretainedTests.swift
//
//
//  Created by Daniel Bachar on 11/8/23.
//
import Afluent
import Foundation
import Testing

struct WithUnretainedTests {
    final class MyType: Sendable {}

    @Test func withUnretainedHolds() async throws {
        let myTypeInstance = MyType()

        try await DeferredTask { 1 }
            .withUnretained(
                myTypeInstance,
                resultSelector: { myType, _ in
                    #expect(myType != nil)
                }
            )
            .execute()
    }

    @Test func withUnretainedThrows() async throws {
        do {
            try await DeferredTask { 1 }
                .withUnretained(MyType(), resultSelector: { _, _ in })
                .execute()
            Issue.record("Should throw if failed to retain")
        } catch {
            #expect(error as? UnretainedError == UnretainedError.failedRetaining)
        }
    }
}
