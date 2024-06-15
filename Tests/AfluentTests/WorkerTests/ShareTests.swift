//
//  ShareTests.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Afluent
import ConcurrencyExtras
import Foundation
import Testing

struct ShareTests {
    #warning("Revisit")
//    @Test func unsharedTaskExecutesRepeatedly() async throws {
//        try await withMainSerialExecutor {
//            try await confirmation(expectedCount: 4) { exp in
//                actor Test {
//                    var arr = [String]()
//                    func append(_ str: String) {
//                        arr.append(str)
//                    }
//                }
//
//                let test = Test()
//
//                let t = DeferredTask {
//                    await test.append("called")
//                    exp()
//                }
//
//                t.run()
//                t.run()
//                t.run()
//                try await t.execute()
//
//                let copy = await test.arr
//                #expect(copy == ["called", "called", "called", "called"])
//            }
//        }
//    }

    @Test func unsharedTaskExecutesRepeatedly_WithResult() async throws {
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

        try await t.execute()
        try await t.execute()
        try await t.execute()

        let copy = await test.arr
        #expect(copy == ["called", "called", "called"])
    }

    @Test func sharedTaskExecutesOnce() async throws {
        try await confirmation(expectedCount: 1) { exp in
            actor Test {
                var arr = [String]()
                func append(_ str: String) {
                    arr.append(str)
                }
            }

            let test = Test()

            let t = DeferredTask {
                await test.append("called")
                exp()
            }.share()

            t.run()
            t.run()
            t.run()
            try await t.execute()

            let copy = await test.arr
            #expect(copy == ["called"])
        }
    }

    @Test func sharedTaskExecutesOnce_WithResult() async throws {
        actor Test {
            var arr = [String]()
            func append(_ str: String) {
                arr.append(str)
            }
        }

        let test = Test()

        let t = DeferredTask {
            await test.append("called")
        }.share()

        try await t.execute()
        try await t.execute()
        try await t.execute()

        let copy = await test.arr
        #expect(copy == ["called"])
    }

    @Test func sharedTaskExecutesOnce_WithResult_SharedToAllSubscribers() async throws {
        let t = DeferredTask {
            1
        }.share()

        let v1 = try await t.execute()
        let v2 = try await t.execute()
        let v3 = try await t.execute()
        #expect(v1 == 1)
        #expect(v2 == 1)
        #expect(v3 == 1)
    }
}
