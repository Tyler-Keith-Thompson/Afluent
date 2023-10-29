//
//  RetryAfterFlatMappingTests.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Foundation
import Afluent
import XCTest

final class RetryAfterFlatMappingTests: XCTestCase {
    func testTaskCanRetryADefinedNumberOfTimes() async throws {
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
        .tryMap { _ in throw URLError(.badURL) }
        .retry(retryCount) { _ in
            DeferredTask {
                await test.append("flatMap")
            }
        }
        
        _ = try await t.result
        
        let copy = await test.arr
        XCTAssertEqual(UInt(copy.count), (retryCount * 2) + 1)
    }
    
    func testTaskCanRetryZero_DoesNothing() async throws {
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
        .tryMap { _ in throw URLError(.badURL) }
        .retry(0) { _ in
            DeferredTask {
                await test.append("flatMap")
            }
        }
        
        _ = try await t.result
        
        let copy = await test.arr
        XCTAssertEqual(UInt(copy.count), 1)
    }
    
    func testTaskCanRetryDefaultsToOnce() async throws {
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
        .tryMap { _ in throw URLError(.badURL) }
        .retry { _ in
            DeferredTask {
                await test.append("flatMap")
            }
        }
        
        _ = try await t.result
        
        let copy = await test.arr
        XCTAssertEqual(UInt(copy.count), 3)
    }
    
    func testTaskCanRetryWithoutError_DoesNothing() async throws {
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
        .retry(10) { _ in
            DeferredTask {
                await test.append("flatMap")
            }
        }
        
        _ = try await t.result
        
        let copy = await test.arr
        XCTAssertEqual(UInt(copy.count), 1)
    }
}
