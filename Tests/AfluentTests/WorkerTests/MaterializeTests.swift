//
//  MaterializeTests.swift
//
//
//  Created by Tyler Thompson on 11/3/23.
//

import Afluent
import ConcurrencyExtras
import Foundation
import Testing

struct MaterializeTests {
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func materializeCapturesSuccesses() async throws {
        let result = try await DeferredTask {
            1
        }
        .materialize()
        .execute()

        try #expect(result.get() == 1)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func materializeCapturesNonCancelErrors() async throws {
        let result = try await DeferredTask {
            throw GeneralError.e1
        }
        .materialize()
        .execute()

        #expect { try result.get() } throws: { error in
            error as? GeneralError == GeneralError.e1
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func dematerializeWithError() async throws {
        let result = try await DeferredTask {
            throw GeneralError.e1
        }
        .materialize()
        .dematerialize()
        .result

        #expect { try result.get() } throws: { error in
            error as? GeneralError == GeneralError.e1
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func dematerializeWithoutError() async throws {
        let result = try await DeferredTask {
            1
        }
        .materialize()
        .dematerialize()
        .execute()

        #expect(result == 1)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func materializeDoesNotInterfereWithCancellation() async throws {
        actor Test {
            var started = false
            var ended = false
            var task: AnyCancellable?

            func start() { started = true }
            func end() { ended = true }
            func setTask(_ cancellable: AnyCancellable?) {
                self.task = cancellable
            }
        }
        let test = Test()
        // The body cancels itself through the stored handle, so it must not start before the handle is stored.
        let taskStored = SingleValueSubject<Void>()
        let sub = SingleValueSubject<Void>()

        await test.setTask(
            DeferredTask {
                try await taskStored.execute()
                await test.start()
                await test.task?.cancel()
            }
            .handleEvents(receiveCancel: {
                try? sub.send()
            })
            .map {
                await test.end()
            }
            .materialize()
            .subscribe())

        try taskStored.send()
        try await sub.execute()

        let started = await test.started
        let ended = await test.ended

        #expect(started)
        #expect(!ended)
    }
}
