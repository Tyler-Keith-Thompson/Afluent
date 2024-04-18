//
//  ReplaceNilSequenceTests.swift
//
//
//  Created by Tyler Thompson on 12/19/23.
//

import Afluent
import Foundation
import Testing

struct ReplaceNilSequenceTests {
    @Test func replaceNilTransformsValue() async throws {
        let val = try await DeferredTask { nil as Int? }
            .toAsyncSequence()
            .replaceNil(with: 0)
            .first()

        #expect(val == 0)
    }

    @Test func replaceNilDoesNotTransformValue_IfValueExists() async throws {
        let val = try await DeferredTask { 1 as Int? }
            .toAsyncSequence()
            .replaceNil(with: 0)
            .first()

        #expect(val == 1)
    }
}
