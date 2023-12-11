//
//  AnyAsyncSequenceTests.swift
//
//
//  Created by Tyler Thompson on 11/28/23.
//

import Afluent
import Foundation
import XCTest

final class AnyAsyncSequenceTests: XCTestCase {
    func testErasureOfAsyncSequence() async throws {
        let val = try await DeferredTask { true }.toAsyncSequence()
            .flatMap { branch -> AnyAsyncSequence<Int> in
                if branch {
                    return DeferredTask { 1 }.toAsyncSequence().eraseToAnyAsyncSequence()
                } else {
                    return DeferredTask { 0 }.toAsyncSequence().eraseToAnyAsyncSequence()
                }
            }.first()

        XCTAssertEqual(val, 1)
    }

    func testErasureOfAsyncSequence_OtherBranch() async throws {
        let val = try await DeferredTask { false }.toAsyncSequence()
            .flatMap { branch -> AnyAsyncSequence<Int> in
                if branch {
                    return DeferredTask { 1 }.toAsyncSequence().eraseToAnyAsyncSequence()
                } else {
                    return DeferredTask { 0 }.toAsyncSequence().eraseToAnyAsyncSequence()
                }
            }.first()

        XCTAssertEqual(val, 0)
    }
}
