//
//  ExecuteOnTaskExecutorTests.swift
//  Afluent
//
//  Created by Annalise Mariottini on 10/10/24.
//

import Afluent
import Foundation
import Testing

#if swift(>=6)
struct ExecuteOnTaskExecutorTests {
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    @Test func testExecutesOnExpectedExecutor() async throws {
        try await DeferredTask { }
            .handleEvents(receiveOutput: { _ in
                dispatchPrecondition(condition: .onQueue(.main))
            })
            .execute(executorPreference: .mainQueue)

        try await DeferredTask { }
            .handleEvents(receiveOutput: { _ in
                dispatchPrecondition(condition: .onQueue(.global(qos: .background)))
            })
            .execute(executorPreference: .globalQueue(qos: .background))

        let queue = DispatchQueue(label: "\(String(describing: Self.self))\(UUID().uuidString)")
        try await DeferredTask { }
            .handleEvents(receiveOutput: { _ in
                dispatchPrecondition(condition: .onQueue(queue))
            })
            .execute(executorPreference: .queue(queue))
    }

    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    @Test func testRunsOnExpectedExecutor() async throws {
        let (stream, continuation) = AsyncStream<Void>.makeStream()

        DeferredTask { }
            .handleEvents(receiveOutput: { _ in
                dispatchPrecondition(condition: .onQueue(.main))
                continuation.yield()
            })
            .run(executorPreference: .mainQueue)

        DeferredTask { }
            .handleEvents(receiveOutput: { _ in
                dispatchPrecondition(condition: .onQueue(.global(qos: .background)))
                continuation.yield()
            })
            .run(executorPreference: .globalQueue(qos: .background))

        let queue = DispatchQueue(label: "\(String(describing: Self.self))\(UUID().uuidString)")
        DeferredTask { }
            .handleEvents(receiveOutput: { _ in
                dispatchPrecondition(condition: .onQueue(queue))
                continuation.yield()
            })
            .run(executorPreference: .queue(queue))

        for await _ in stream.chunks(ofCount: 3) {
            break
        }
    }
}
#endif
