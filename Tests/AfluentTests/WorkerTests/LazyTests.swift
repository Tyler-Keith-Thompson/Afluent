//
//  LazyTests.swift
//
//
//  Created by Tyler Thompson on 10/30/23.
//

import Foundation
import Afluent
import XCTest

final class LazyTests: XCTestCase {
    func testLazyCachesResult() async throws {
        actor Test {
            var callCount = 0
            func increment() { callCount += 1 }
        }
        let test = Test()
        
        try? await DeferredTask {
            await test.increment()
        }
        .lazy()
        .tryMap {
            throw URLError(.badURL)
        }
        .retry()
        .execute()
        
        let callCount = await test.callCount
        XCTAssertEqual(callCount, 1)
    }
    
    func testLazyDoesNotAffectFullChain() async throws {
        actor Test {
            var callCount = 0
            func increment() { callCount += 1 }
        }
        let test = Test()
        
        try? await DeferredTask {
            await test.increment()
        }
        .lazy()
        .map {
            await test.increment()
        }
        .tryMap {
            throw URLError(.badURL)
        }
        .retry()
        .execute()
        
        let callCount = await test.callCount
        XCTAssertEqual(callCount, 3)
    }
}
