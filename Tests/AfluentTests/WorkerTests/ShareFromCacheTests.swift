//
//  ShareFromCacheTests.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import ConcurrencyExtras
import Foundation
import XCTest
@testable import Afluent

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
final class ShareFromCacheTests: XCTestCase {
    func testSharingFromCacheWithNoKey() async throws {
        try await withMainSerialExecutor {
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
    }

    func testSharingFromCacheAfterCompletion() async throws {
        try await withMainSerialExecutor {
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
    }

    func testSharingFromCacheAfterError() async throws {
        await withMainSerialExecutor {
            actor Test {
                var callCount = 0

                func increment() {
                    callCount += 1
                }
            }
            enum Err: Error { case e1 }
            let test = Test()
            let cache = AUOWCache()

            @Sendable func unitOfWork() -> some AsynchronousUnitOfWork<String> {
                DeferredTask { await test.increment(); throw Err.e1 }
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

            let err1: Error?
            let err2: Error?
            do {
                _ = try await d1
                err1 = nil
            } catch {
                err1 = error
            }
            do {
                _ = try await d2
                err2 = nil
            } catch {
                err2 = error
            }

            XCTAssertEqual(err1 as? Err, Err.e1)
            XCTAssertEqual(err2 as? Err, Err.e1)

            let callCount = await test.callCount
            XCTAssertEqual(callCount, 2)
        }
    }

    func testSharingFromCacheWithKey() async throws {
        try await withMainSerialExecutor {
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
}
