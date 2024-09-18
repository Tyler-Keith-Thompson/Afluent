//
//  FlatMapTests.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Afluent
import Foundation
import Testing

struct FlatMapTests {
    @Test func flatMapTransformsValue() async throws {
        let val = try await DeferredTask { 1 }
            .flatMap { val in
                DeferredTask { val }
                    .map { String(describing: $0) }
            }
            .execute()

        #expect(val == "1")
    }

    @Test func flatMapOrdersCorrectly() async throws {
        actor Test {
            var arr = [String]()
            func append(_ str: String) {
                arr.append(str)
            }
        }

        let test = Test()

        try await DeferredTask {
            await Task.yield()
            await test.append("1")
        }.flatMap {
            DeferredTask {
                await test.append("2")
            }
        }
        .execute()

        let copy = await test.arr
        #expect(copy == ["1", "2"])
    }

    @Test func flatMapOrdersCorrectly_No_Throwing() async throws {
        actor Test {
            var arr = [String]()
            func append(_ str: String) {
                arr.append(str)
            }
        }

        let test = Test()

        try await DeferredTask {
            await Task.yield()
            await test.append("1")
        }.flatMap {
            DeferredTask {
                await test.append("2")
            }
        }
        .execute()

        let copy = await test.arr
        #expect(copy == ["1", "2"])
    }

    @Test func flatMapThrowsError() async throws {
        let val = try await DeferredTask { 1 }
            .flatMap { _ in
                DeferredTask {
                    throw GeneralError.e1
                }
            }
            .result

        #expect { try val.get() } throws: { error in
            error as? GeneralError == GeneralError.e1
        }
    }
}
