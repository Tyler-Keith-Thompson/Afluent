//
//  CancelTests.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Afluent
import ConcurrencyExtras
import Foundation
import Testing

struct CancelTests {
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func deferredTaskCancelledBeforeItStarts() async throws {
        let task = DeferredTask { }
        task.cancel()
        let res = try await task.result
        #expect(throws: (any Error).self) { try res.get() }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.milliseconds(10))) func deferredTaskCancelledBeforeItEnds() async throws {
        try await withMainSerialExecutor {
            actor Test {
                var started = false
                var ended = false

                func start() { started = true }
                func end() { ended = true }
            }
            let test = Test()

            let sub = SingleValueSubject<Void>()
            var task: AnyCancellable?
            task = DeferredTask {
                await test.start()
                task?.cancel()
            }
            .handleEvents(receiveCancel: {
                try? sub.send()
            })
            .map {
                await test.end()
            }
            .subscribe()

            try await sub.execute()

            let started = await test.started
            let ended = await test.ended

            #expect(started)
            #expect(!ended)
        }
    }
}
