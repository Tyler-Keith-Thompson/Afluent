//
//  CatchTests.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Afluent
import Foundation
import XCTest

final class CatchTests: XCTestCase {
    func testCatchDoesNotInterfereWithNoFailure() async throws {
        let val = try await DeferredTask { 1 }
            .catch { _ in DeferredTask { 2 } }
            .execute()

        XCTAssertEqual(val, 1)
    }

    func testCatchDoesNotThrowError() async throws {
        let val = try await DeferredTask { 1 }
            .tryMap { _ in throw URLError(.badURL) }
            .catch { error -> DeferredTask<Int> in
                XCTAssertEqual(error as? URLError, URLError(.badURL))
                return DeferredTask { 2 }
            }
            .result

        XCTAssertEqual(try val.get(), 2)
    }

    func testCatchSpecificError() async throws {
        enum Err: Error, Equatable {
            case e1
            case e2
        }

        let val = try await DeferredTask { 1 }
            .tryMap { _ in throw Err.e1 }
            .catch(Err.e1) { error -> DeferredTask<Int> in
                XCTAssertEqual(error, .e1)
                return DeferredTask { 2 }
            }
            .result

        XCTAssertEqual(try val.get(), 2)
    }

    func testCatchSpecificError_DoesNotCatchWrongError() async throws {
        enum Err: Error, Equatable {
            case e1
            case e2
        }

        let val = try await DeferredTask { 1 }
            .tryMap { _ in throw Err.e2 }
            .catch(Err.e1) { error -> DeferredTask<Int> in
                XCTAssertEqual(error, .e1)
                return DeferredTask { 2 }
            }
            .result

        XCTAssertThrowsError(try val.get()) { error in
            XCTAssertEqual(error as? Err, .e2)
        }
    }

    func testTryCatchDoesNotInterfereWithNoFailure() async throws {
        let val = try await DeferredTask { 1 }
            .tryCatch { _ in DeferredTask { 2 } }
            .execute()

        XCTAssertEqual(val, 1)
    }

    func testTryCatchDoesNotThrowError() async throws {
        let val = try await DeferredTask { 1 }
            .tryMap { _ in throw URLError(.badURL) }
            .tryCatch { error -> DeferredTask<Int> in
                XCTAssertEqual(error as? URLError, URLError(.badURL))
                return DeferredTask { 2 }
            }
            .result

        XCTAssertEqual(try val.get(), 2)
    }

    func testTryCatchSpecificError() async throws {
        enum Err: Error, Equatable {
            case e1
            case e2
        }

        let val = try await DeferredTask { 1 }
            .tryMap { _ in throw Err.e1 }
            .tryCatch(Err.e1) { error -> DeferredTask<Int> in
                XCTAssertEqual(error, .e1)
                return DeferredTask { 2 }
            }
            .result

        XCTAssertEqual(try val.get(), 2)
    }

    func testTryCatchSpecificError_DoesNotCatchWrongError() async throws {
        enum Err: Error, Equatable {
            case e1
            case e2
        }

        let val = try await DeferredTask { 1 }
            .tryMap { _ in throw Err.e2 }
            .tryCatch(Err.e1) { error -> DeferredTask<Int> in
                XCTAssertEqual(error, .e1)
                return DeferredTask { 2 }
            }
            .result

        XCTAssertThrowsError(try val.get()) { error in
            XCTAssertEqual(error as? Err, .e2)
        }
    }
}
