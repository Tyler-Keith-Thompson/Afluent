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

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
struct MaterializeTests {
    @Test func materializeCapturesSuccesses() async throws {
        let result = try await DeferredTask {
            1
        }
        .materialize()
        .execute()

        try #expect(result.get() == 1)
    }

    @Test func materializeCapturesNonCancelErrors() async throws {
        let result = try await DeferredTask {
            throw URLError(.badURL)
        }
        .materialize()
        .execute()

        #expect { try result.get() } throws: { error in
            error as? URLError == URLError(.badURL)
        }
    }

    @Test func dematerializeWithError() async throws {
        let result = try await DeferredTask {
            throw URLError(.badURL)
        }
        .materialize()
        .dematerialize()
        .result

        #expect { try result.get() } throws: { error in
            error as? URLError == URLError(.badURL)
        }
    }

    @Test func dematerializeWithoutError() async throws {
        let result = try await DeferredTask {
            1
        }
        .materialize()
        .dematerialize()
        .execute()

        #expect(result == 1)
    }

    @Test func materializeDoesNotInterfereWithCancellation() async throws {
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
            .materialize()
            .subscribe()

            try await sub.execute()

            let started = await test.started
            let ended = await test.ended

            #expect(started)
            #expect(!ended)
        }
    }
}
