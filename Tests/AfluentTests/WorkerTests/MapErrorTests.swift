//
//  MapErrorTests.swift
//
//
//  Created by Tyler Thompson on 11/2/23.
//

import Afluent
import Foundation
import Testing

struct MapErrorTests {
    @Test func mapErrorChangesError() async throws {
        enum Err: Error {
            case e1
        }

        let result = try await DeferredTask {
            throw URLError(.badURL)
        }
        .mapError { _ in Err.e1 }
        .result

        #expect { try result.get() } throws: { error in
            error as? Err == .e1
        }
    }

    @Test func mapSpecificErrorChangesError() async throws {
        enum Err: Error {
            case e1
        }

        let result = try await DeferredTask {
            throw URLError(.badURL)
        }
        .mapError(URLError(.badURL)) { _ in Err.e1 }
        .result

        #expect { try result.get() } throws: { error in
            error as? Err == .e1
        }
    }

    @Test func mapErrorDoesNothingWithoutAnError() async throws {
        enum Err: Error {
            case e1
        }

        let result = try await DeferredTask {
            1
        }
        .mapError { _ in Err.e1 }
        .result

        try #expect(result.get() == 1)
    }

    @Test func mapSpecificErrorDoesNothingWithoutThatErrorBeingThrown() async throws {
        enum Err: Error {
            case e1
        }

        let result = try await DeferredTask {
            throw URLError(.badServerResponse)
        }
        .mapError(URLError(.badURL)) { _ in Err.e1 }
        .result

        #expect { try result.get() } throws: { error in
            error as? URLError == URLError(.badServerResponse)
        }
    }
}
