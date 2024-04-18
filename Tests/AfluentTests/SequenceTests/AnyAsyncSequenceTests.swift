//
//  AnyAsyncSequenceTests.swift
//
//
//  Created by Tyler Thompson on 11/28/23.
//

import Afluent
import Foundation
import Testing

struct AnyAsyncSequenceTests {
    @Test func erasureOfAsyncSequence() async throws {
        let val = try await DeferredTask { true }.toAsyncSequence()
            .flatMap { branch -> AnyAsyncSequence<Int> in
                if branch {
                    return DeferredTask { 1 }.toAsyncSequence().eraseToAnyAsyncSequence()
                } else {
                    return DeferredTask { 0 }.toAsyncSequence().eraseToAnyAsyncSequence()
                }
            }.first()

        #expect(val == 1)
    }

    @Test func erasureOfAsyncSequence_OtherBranch() async throws {
        let val = try await DeferredTask { false }.toAsyncSequence()
            .flatMap { branch -> AnyAsyncSequence<Int> in
                if branch {
                    return DeferredTask { 1 }.toAsyncSequence().eraseToAnyAsyncSequence()
                } else {
                    return DeferredTask { 0 }.toAsyncSequence().eraseToAnyAsyncSequence()
                }
            }.first()

        #expect(val == 0)
    }
}
