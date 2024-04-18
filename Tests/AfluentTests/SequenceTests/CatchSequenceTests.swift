//
//  CatchSequenceTests.swift
//
//
//  Created by Tyler Thompson on 11/28/23.
//

import Afluent
import Foundation
import Testing

struct CatchSequenceTests {
    @Test func testCatchDoesNotInterfereWithNoFailure() async throws {
        let val = try await DeferredTask { 1 }.toAsyncSequence()
            .catch { _ in DeferredTask { 2 }.toAsyncSequence() }
            .first()

        #expect(val == 1)
    }

    @Test func testCatchDoesNotThrowError() async throws {
        let val = await Task {
            try await DeferredTask { 1 }.toAsyncSequence()
                .map { _ -> Int in throw URLError(.badURL) }
                .catch { error in
                    #expect(error as? URLError == URLError(.badURL))
                    return DeferredTask { 2 }.toAsyncSequence()
                }
                .first()
        }.result

        try #expect(val.get() == 2)
    }

    @Test func testCatchSpecificError() async throws {
        enum Err: Error, Equatable {
            case e1
            case e2
        }

        let val = await Task {
            try await DeferredTask { 1 }.toAsyncSequence()
                .map { _ -> Int in throw Err.e1 }
                .catch(Err.e1) { error in
                    #expect(error == .e1)
                    return DeferredTask { 2 }.toAsyncSequence()
                }
                .first()
        }.result

        try #expect(val.get() == 2)
    }

    @Test func testCatchSpecificError_DoesNotCatchWrongError() async throws {
        enum Err: Error, Equatable {
            case e1
            case e2
        }

        let val = await Task {
            try await DeferredTask { 1 }.toAsyncSequence()
                .map { _ -> Int in throw Err.e2 }
                .catch(Err.e1) { error in
                    #expect(error == .e1)
                    return DeferredTask { 2 }.toAsyncSequence()
                }
                .first()
        }
        .result

        #expect { try val.get() } throws: { error in
            error as? Err == .e2
        }
    }

    @Test func testTryCatchDoesNotInterfereWithNoFailure() async throws {
        let val = try await DeferredTask { 1 }.toAsyncSequence()
            .tryCatch { _ in DeferredTask { 2 }.toAsyncSequence() }
            .first()

        #expect(val == 1)
    }

    @Test func testTryCatchDoesNotThrowError() async throws {
        let val = await Task {
            try await DeferredTask { 1 }.toAsyncSequence()
                .map { _ -> Int in throw URLError(.badURL) }
                .tryCatch { error in
                    #expect(error as? URLError == URLError(.badURL))
                    return DeferredTask { 2 }.toAsyncSequence()
                }
                .first()
        }
        .result

        try #expect(val.get() == 2)
    }

    @Test func testTryCatchSpecificError() async throws {
        enum Err: Error, Equatable {
            case e1
            case e2
        }

        let val = await Task {
            try await DeferredTask { 1 }.toAsyncSequence()
                .map { _ -> Int in throw Err.e1 }
                .tryCatch(Err.e1) { error in
                    #expect(error == .e1)
                    return DeferredTask { 2 }.toAsyncSequence()
                }
                .first()
        }
        .result

        try #expect(val.get() == 2)
    }

    @Test func testTryCatchSpecificError_DoesNotCatchWrongError() async throws {
        enum Err: Error, Equatable {
            case e1
            case e2
        }

        let val = await Task {
            try await DeferredTask { 1 }.toAsyncSequence()
                .map { _ -> Int in throw Err.e2 }
                .tryCatch(Err.e1) { error in
                    #expect(error == .e1)
                    return DeferredTask { 2 }.toAsyncSequence()
                }
                .first()
        }
        .result

        #expect { try val.get() } throws: { error in
            error as? Err == .e2
        }
    }
}
