//
//  ReplaceErrorTests.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Afluent
import Foundation
import Testing

struct ReplaceErrorTests {
    @Test func replaceErrorTransformsValue() async throws {
        let val = try await DeferredTask { throw URLError(.badURL) }
            .replaceError(with: -1)
            .execute()

        #expect(val == -1)
    }

    @Test func replaceNilDoesNotTransformValue_IfNoErrorThrown() async throws {
        let val = try await DeferredTask { 1 }
            .replaceError(with: -1)
            .execute()

        #expect(val == 1)
    }
}
