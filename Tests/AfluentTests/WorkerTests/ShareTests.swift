//
//  ShareTests.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Afluent
import Clocks
import ConcurrencyExtras
import Foundation
import Testing

struct ShareTests {
    @Test func unsharedTaskExecutesRepeatedly() async throws {
        try await confirmation(expectedCount: 4) { exp in
            try await withMainSerialExecutor {
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
                }

                t.run()
                t.run()
                t.run()
                try await t.execute()

                let copy = await test.arr
                #expect(copy == ["called", "called", "called", "called"])
            }
        }
    }

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
            UUID().uuidString
        }.share()

        let v1 = try await t.execute()
        let v2 = try await t.execute()
        let v3 = try await t.execute()
        #expect(v1 == v2)
        #expect(v2 == v3)
    }

    @Test func sharedTask_cancelsUpstreamWhenCancelled() async throws {
        let clock = TestClock()
        let startedSleeping = SingleValueSubject<Void>()

        let t = DeferredTask {
            async let _sleep = Result { try await Task.sleep(for: .milliseconds(10), clock: clock) }
            try startedSleeping.send()
            let sleep = await _sleep
            #expect(throws: CancellationError.self) {
                try sleep.get()
            }
            return UUID().uuidString
        }.share()

        async let _r1 = Result { try await t.execute() }
        async let _r2 = Result { try await t.execute() }
        async let _r3 = Result { try await t.execute() }

        try await startedSleeping.execute()
        t.cancel()
        await clock.advance(by: .milliseconds(11))

        let r1 = await _r1
        let r2 = await _r2
        let r3 = await _r3

        #expect(throws: CancellationError.self) {
            try r1.get()
        }
        #expect(throws: CancellationError.self) {
            try r2.get()
        }
        #expect(throws: CancellationError.self) {
            try r3.get()
        }
    }
}
