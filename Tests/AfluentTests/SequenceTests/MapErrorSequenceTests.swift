//
//  MapErrorSequenceTests.swift
//
//
//  Created by Tyler Thompson on 12/17/23.
//

import Afluent
import Foundation
import Testing

struct MapErrorSequenceTests {
    @Test func mapErrorChangesError() async throws {
        enum Err: Error {
            case e1
        }

        let result = await Task {
            try await DeferredTask {
                throw GeneralError.e1
            }
            .toAsyncSequence()
            .mapError { _ in Err.e1 }
            .first()
        }
        .result

        #expect { try result.get() } throws: { error in
            error as? Err == .e1
        }
    }

    @Test func mapSpecificErrorChangesError() async throws {
        enum Err: Error {
            case e1
        }

        let result = await Task {
            try await DeferredTask {
                throw GeneralError.e1
            }
            .toAsyncSequence()
            .mapError(GeneralError.e1) { _ in Err.e1 }
            .first()
        }
        .result

        #expect { try result.get() } throws: { error in
            error as? Err == .e1
        }
    }

    @Test func mapErrorDoesNothingWithoutAnError() async throws {
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

        try #expect(result.get() == 1)
    }

    @Test func mapSpecificErrorDoesNothingWithoutThatErrorBeingThrown() async throws {
        enum Err: Error {
            case e1
        }

        let result = await Task {
            try await DeferredTask {
                throw GeneralError.e2
            }
            .toAsyncSequence()
            .mapError(GeneralError.e1) { _ in Err.e1 }
            .first()
        }
        .result

        #expect { try result.get() } throws: { error in
            error as? GeneralError == .e2
        }
    }
}
