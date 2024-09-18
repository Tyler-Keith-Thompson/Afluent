//
//  CatchTests.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Afluent
import Foundation
import Testing

struct CatchTests {
    @Test func catchDoesNotInterfereWithNoFailure() async throws {
        let val = try await DeferredTask { 1 }
            .catch { _ in DeferredTask { 2 } }
            .execute()

        #expect(val == 1)
    }

    @Test func catchDoesNotThrowError() async throws {
        let val = try await DeferredTask { 1 }
            .tryMap { _ in throw GeneralError.e1 }
            .catch { error -> DeferredTask<Int> in
                #expect(error as? GeneralError == GeneralError.e1)
                return DeferredTask { 2 }
            }
            .result

        try #expect(val.get() == 2)
    }

    @Test func catchSpecificError() async throws {
        enum Err: Error, Equatable {
            case e1
            case e2
        }

        let val = try await DeferredTask { 1 }
            .tryMap { _ in throw Err.e1 }
            .catch(Err.e1) { error -> DeferredTask<Int> in
                #expect(error == .e1)
                return DeferredTask { 2 }
            }
            .result

        try #expect(val.get() == 2)
    }

    @Test func catchSpecificError_DoesNotCatchWrongError() async throws {
        enum Err: Error, Equatable {
            case e1
            case e2
        }

        let val = try await DeferredTask { 1 }
            .tryMap { _ in throw Err.e2 }
            .catch(Err.e1) { error -> DeferredTask<Int> in
                #expect(error == .e1)
                return DeferredTask { 2 }
            }
            .result

        #expect { try val.get() } throws: { error in
            error as? Err == .e2
        }
    }

    @Test func tryCatchDoesNotInterfereWithNoFailure() async throws {
        let val = try await DeferredTask { 1 }
            .tryCatch { _ in DeferredTask { 2 } }
            .execute()

        #expect(val == 1)
    }

    @Test func tryCatchDoesNotThrowError() async throws {
        let val = try await DeferredTask { 1 }
            .tryMap { _ in throw GeneralError.e1 }
            .tryCatch { error -> DeferredTask<Int> in
                #expect(error as? GeneralError == GeneralError.e1)
                return DeferredTask { 2 }
            }
            .result

        try #expect(val.get() == 2)
    }

    @Test func tryCatchSpecificError() async throws {
        enum Err: Error, Equatable {
            case e1
            case e2
        }

        let val = try await DeferredTask { 1 }
            .tryMap { _ in throw Err.e1 }
            .tryCatch(Err.e1) { error -> DeferredTask<Int> in
                #expect(error == .e1)
                return DeferredTask { 2 }
            }
            .result

        try #expect(val.get() == 2)
    }

    @Test func tryCatchSpecificError_DoesNotCatchWrongError() async throws {
        enum Err: Error, Equatable {
            case e1
            case e2
        }

        let val = try await DeferredTask { 1 }
            .tryMap { _ in throw Err.e2 }
            .tryCatch(Err.e1) { error -> DeferredTask<Int> in
                #expect(error == .e1)
                return DeferredTask { 2 }
            }
            .result

        #expect { try val.get() } throws: { error in
            error as? Err == .e2
        }
    }
}
