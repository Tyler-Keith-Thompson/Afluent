//
//  MapErrorTests.swift
//
//
//  Created by Tyler Thompson on 11/2/23.
//

import Afluent
import Foundation
import XCTest

final class MapErrorTests: XCTestCase {
    func testMapErrorChangesError() async throws {
        enum Err: Error {
            case e1
        }

        let result = try await DeferredTask {
            throw URLError(.badURL)
        }
        .mapError { _ in Err.e1 }
        .result

        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(error as? Err, .e1)
        }
    }

    func testMapSpecificErrorChangesError() async throws {
        enum Err: Error {
            case e1
        }

        let result = try await DeferredTask {
            throw URLError(.badURL)
        }
        .mapError(URLError(.badURL)) { _ in Err.e1 }
        .result

        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(error as? Err, .e1)
        }
    }

    func testMapErrorDoesNothingWithoutAnError() async throws {
        enum Err: Error {
            case e1
        }

        let result = try await DeferredTask {
            1
        }
        .mapError { _ in Err.e1 }
        .result

        XCTAssertEqual(try result.get(), 1)
    }

    func testMapSpecificErrorDoesNothingWithoutThatErrorBeingThrown() async throws {
        enum Err: Error {
            case e1
        }

        let result = try await DeferredTask {
            throw URLError(.badServerResponse)
        }
        .mapError(URLError(.badURL)) { _ in Err.e1 }
        .result

        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(error as? URLError, URLError(.badServerResponse))
        }
    }
}
