//
//  CatchSequenceTests.swift
//
//
//  Created by Tyler Thompson on 11/28/23.
//

import Foundation
import Afluent
import XCTest

final class CatchSequenceTests: XCTestCase {
    func testCatchDoesNotInterfereWithNoFailure() async throws {
        let val = try await DeferredTask { 1 }.toAsyncSequence()
            .catch { _ in DeferredTask { 2 }.toAsyncSequence() }
            .first { _ in true }
        
        XCTAssertEqual(val, 1)
    }
    
    func testCatchDoesNotThrowError() async throws {
        let val = await Task {
            try await DeferredTask { 1 }.toAsyncSequence()
                .map { _ -> Int in throw URLError(.badURL) }
                .catch { error in
                    XCTAssertEqual(error as? URLError, URLError(.badURL))
                    return DeferredTask { 2 }.toAsyncSequence()
                }
                .first { _ in true }
        }.result
        
        XCTAssertEqual(try val.get(), 2)
    }
    
    func testCatchSpecificError() async throws {
        enum Err: Error, Equatable {
            case e1
            case e2
        }
        
        let val = await Task {
            try await DeferredTask { 1 }.toAsyncSequence()
                .map { _ -> Int in throw Err.e1 }
                .catch(Err.e1) { error in
                    XCTAssertEqual(error, .e1)
                    return DeferredTask { 2 }.toAsyncSequence()
                }
                .first { _ in true }
        }.result
        
        XCTAssertEqual(try val.get(), 2)
    }
    
    func testCatchSpecificError_DoesNotCatchWrongError() async throws {
        enum Err: Error, Equatable {
            case e1
            case e2
        }
        
        let val = await Task {
            try await DeferredTask { 1 }.toAsyncSequence()
                .map { _ -> Int in throw Err.e2 }
                .catch(Err.e1) { error in
                    XCTAssertEqual(error, .e1)
                    return DeferredTask { 2 }.toAsyncSequence()
                }
                .first { _ in true }
        }
        .result
        
        XCTAssertThrowsError(try val.get()) { error in
            XCTAssertEqual(error as? Err, .e2)
        }
    }

    func testTryCatchDoesNotInterfereWithNoFailure() async throws {
        let val = try await DeferredTask { 1 }.toAsyncSequence()
            .tryCatch { _ in DeferredTask { 2 }.toAsyncSequence() }
            .first { _ in true }
        
        XCTAssertEqual(val, 1)
    }
    
    func testTryCatchDoesNotThrowError() async throws {
        let val = await Task {
            try await DeferredTask { 1 }.toAsyncSequence()
                .map { _ -> Int in throw URLError(.badURL) }
                .tryCatch { error in
                    XCTAssertEqual(error as? URLError, URLError(.badURL))
                    return DeferredTask { 2 }.toAsyncSequence()
                }
                .first { _ in true }
        }
        .result
        
        XCTAssertEqual(try val.get(), 2)
    }
    
    func testTryCatchSpecificError() async throws {
        enum Err: Error, Equatable {
            case e1
            case e2
        }
        
        let val = await Task {
            try await DeferredTask { 1 }.toAsyncSequence()
                .map { _ -> Int in throw Err.e1 }
                .tryCatch(Err.e1) { error in
                    XCTAssertEqual(error, .e1)
                    return DeferredTask { 2 }.toAsyncSequence()
                }
                .first { _ in true }
        }
        .result
        
        XCTAssertEqual(try val.get(), 2)
    }
    
    func testTryCatchSpecificError_DoesNotCatchWrongError() async throws {
        enum Err: Error, Equatable {
            case e1
            case e2
        }
        
        let val = await Task {
            try await DeferredTask { 1 }.toAsyncSequence()
                .map { _ -> Int in throw Err.e2 }
                .tryCatch(Err.e1) { error in
                    XCTAssertEqual(error, .e1)
                    return DeferredTask { 2 }.toAsyncSequence()
                }
                .first { _ in true }
        }
        .result
        
        XCTAssertThrowsError(try val.get()) { error in
            XCTAssertEqual(error as? Err, .e2)
        }
    }
}
