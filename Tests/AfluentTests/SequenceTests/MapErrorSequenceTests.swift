//
//  MapErrorSequenceTests.swift
//
//
//  Created by Tyler Thompson on 12/17/23.
//

import Afluent
import Foundation
import XCTest

final class MapErrorSequenceTests: XCTestCase {
    func testMapErrorChangesError() async throws {
        enum Err: Error {
            case e1
        }

        let result = await Task {
            try await DeferredTask {
                throw URLError(.badURL)
            }
            .toAsyncSequence()
            .mapError { _ in Err.e1 }
            .first()
        }
        .result

        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(error as? Err, .e1)
        }
    }

    func testMapSpecificErrorChangesError() async throws {
        enum Err: Error {
            case e1
        }

        let result = await Task {
            try await DeferredTask {
                throw URLError(.badURL)
            }
            .toAsyncSequence()
            .mapError(URLError(.badURL)) { _ in Err.e1 }
            .first()
        }
        .result

        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(error as? Err, .e1)
        }
    }

    func testMapErrorDoesNothingWithoutAnError() async throws {
        enum Err: Error {
            case e1
        }

        let result = await Task {
            try await DeferredTask {
                1
            }
            .toAsyncSequence()
            .mapError { _ in Err.e1 }
            .first()
        }
        .result

        XCTAssertEqual(try result.get(), 1)
    }

    func testMapSpecificErrorDoesNothingWithoutThatErrorBeingThrown() async throws {
        enum Err: Error {
            case e1
        }

        let result = await Task {
            try await DeferredTask {
                throw URLError(.badServerResponse)
            }
            .toAsyncSequence()
            .mapError(URLError(.badURL)) { _ in Err.e1 }
            .first()
        }
        .result

        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(error as? URLError, URLError(.badServerResponse))
        }
    }
}
