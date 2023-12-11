//
//  ShareFromCacheTests.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Foundation
import XCTest
@testable import Afluent

final class ShareFromCacheTests: XCTestCase {
    func testSharingFromCacheWithNoKey() async throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] == "true")
        actor Test {
            var callCount = 0

            func increment() {
                callCount += 1
            }
        }
        let test = Test()
        let cache = AUOWCache()

        @Sendable func unitOfWork() -> some AsynchronousUnitOfWork<String> {
            DeferredTask { await test.increment(); return UUID().uuidString }
                .delay(for: .milliseconds(10))
                .shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation)
        }

        let uow = unitOfWork()
        async let d1 = uow.execute()
        XCTAssertFalse(cache.cache.isEmpty)
        async let d2 = DeferredTask { }
            .delay(for: .milliseconds(5))
            .flatMap {
                XCTAssertFalse(cache.cache.isEmpty)
                let uow = unitOfWork()
                let o1 = try ObjectIdentifier(XCTUnwrap(cache.cache[XCTUnwrap(cache.cache.keys.first)]))
                let o2 = try ObjectIdentifier(XCTUnwrap(uow as AnyObject))
                XCTAssertEqual(o1, o2)
                return uow
            }
            .execute()

        _ = try await d1
        _ = try await d2

        let callCount = await test.callCount
        XCTAssertEqual(callCount, 1)
    }

    func testSharingFromCacheAfterCompletion() async throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] == "true")
        actor Test {
            var callCount = 0

            func increment() {
                callCount += 1
            }
        }
        let test = Test()
        let cache = AUOWCache()

        @Sendable func unitOfWork() -> some AsynchronousUnitOfWork<String> {
            DeferredTask { await test.increment(); return UUID().uuidString }
                .delay(for: .milliseconds(10))
                .shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation)
        }

        let uow = unitOfWork()
        async let d1 = uow.execute()
        XCTAssertFalse(cache.cache.isEmpty)
        async let d2 = DeferredTask { }
            .delay(for: .milliseconds(15))
            .flatMap {
                XCTAssert(cache.cache.isEmpty)
                return unitOfWork()
            }
            .execute()

        _ = try await d1
        _ = try await d2

        let callCount = await test.callCount
        XCTAssertEqual(callCount, 2)
    }

    func testSharingFromCacheWithKey() async throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] == "true")
        actor Test {
            var callCount = 0

            func increment() {
                callCount += 1
            }
        }
        let test = Test()
        let cache = AUOWCache()

        @Sendable func unitOfWork() -> some AsynchronousUnitOfWork<String> {
            DeferredTask { await test.increment(); return UUID().uuidString }
                .delay(for: .milliseconds(10))
                .shareFromCache(cache, strategy: .cacheUntilCompletionOrCancellation, keys: 1)
        }

        let uow = unitOfWork()
        async let d1 = uow.execute()
        XCTAssertFalse(cache.cache.isEmpty)
        async let d2 = DeferredTask { }
            .delay(for: .milliseconds(5))
            .flatMap { unitOfWork() }
            .execute()

        _ = try await d1
        _ = try await d2

        let callCount = await test.callCount
        XCTAssertEqual(callCount, 1)
    }
}
