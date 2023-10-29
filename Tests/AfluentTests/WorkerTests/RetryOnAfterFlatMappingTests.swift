//
//  RetryOnAfterFlatMappingTests.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Foundation
import Afluent
import XCTest

final class RetryOnAfterFlatMappingTests: XCTestCase {
    func testTaskCanRetryADefinedNumberOfTimes() async throws {
        enum Err: Error, Equatable {
            case e1
        }
        actor Test {
            var arr = [String]()
            func append(_ str: String) {
                arr.append(str)
            }
        }
        
        let test = Test()
        let retryCount = UInt.random(in: 2...10)
        
        let t = DeferredTask {
            await test.append("called")
        }
        .tryMap { _ in throw Err.e1 }
        .retry(retryCount, on: Err.e1) { _ in
            DeferredTask {
                await test.append("flatMap")
            }
        }
        
        _ = try await t.result
        
        let copy = await test.arr
        XCTAssertEqual(UInt(copy.count), (retryCount * 2) + 1)
    }
    
    func testTaskCanRetryZero_DoesNothing() async throws {
        enum Err: Error, Equatable {
            case e1
        }
        actor Test {
            var arr = [String]()
            func append(_ str: String) {
                arr.append(str)
            }
        }
        
        let test = Test()
        
        let t = DeferredTask {
            await test.append("called")
        }
        .tryMap { _ in throw Err.e1 }
        .retry(0, on: Err.e1) { _ in
            DeferredTask {
                await test.append("flatMap")
            }
        }
        
        _ = try await t.result
        
        let copy = await test.arr
        XCTAssertEqual(UInt(copy.count), 1)
    }
    
    func testTaskCanRetryDefaultsToOnce() async throws {
        enum Err: Error, Equatable {
            case e1
        }
        actor Test {
            var arr = [String]()
            func append(_ str: String) {
                arr.append(str)
            }
        }
        
        let test = Test()
        
        let t = DeferredTask {
            await test.append("called")
        }
        .tryMap { _ in throw Err.e1 }
        .retry(on: Err.e1) { _ in
            DeferredTask {
                await test.append("flatMap")
            }
        }
        
        _ = try await t.result
        
        let copy = await test.arr
        XCTAssertEqual(UInt(copy.count), 3)
    }
    
    func testTaskCanRetryWithoutError_DoesNothing() async throws {
        enum Err: Error, Equatable {
            case e1
        }
        actor Test {
            var arr = [String]()
            func append(_ str: String) {
                arr.append(str)
            }
        }
        
        let test = Test()
        
        let t = DeferredTask {
            await test.append("called")
        }
        .retry(10, on: Err.e1) { _ in
            DeferredTask {
                await test.append("flatMap")
            }
        }
        
        _ = try await t.result
        
        let copy = await test.arr
        XCTAssertEqual(UInt(copy.count), 1)
    }
}
