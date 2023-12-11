//
//  UnwrapOrThrowTests.swift
//
//
//  Created by Tyler Thompson on 11/2/23.
//

import Afluent
import Foundation
import XCTest

final class UnwrapOrThrowTests: XCTestCase {
    func testUnwrapThrowsErrorIfOptionalIsNone() async throws {
        enum Err: Error {
            case e1
        }

        let result = try await DeferredTask {
            nil as Int?
        }
        .unwrap(orThrow: Err.e1)
        .result

        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(error as? Err, .e1)
        }
    }

    func testUnwrapThrowsErrorIfOptionalIsSome() async throws {
        enum Err: Error {
            case e1
        }

        let result = try await DeferredTask {
            1 as Int?
        }
        .unwrap(orThrow: Err.e1)
        .result

        XCTAssertEqual(try result.get(), 1)
    }
}
