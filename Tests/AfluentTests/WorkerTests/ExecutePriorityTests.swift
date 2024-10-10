//
//  ExecutePriorityTests.swift
//  Afluent
//
//  Created by Annalise Mariottini on 10/10/24.
//

import Afluent
import Foundation
@_spi(Experimental) import Testing

#if swift(>=6)
struct ExecutePriorityTests {
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    @Test(.serialized, arguments: [TaskPriority.background, .low, .medium, .high, .userInitiated].map(\.rawValue))
    func testExecutesWithExpectedPriority(priority: UInt8) async throws {
        let executor = TestExecutor()
        try await DeferredTask { }
            .execute(executorPreference: executor, priority: TaskPriority(rawValue: priority))
        let receivedPriority = try await executor.receivedPriority.execute()
        #expect(receivedPriority == priority)
    }

    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    @Test(.serialized, arguments: [TaskPriority.background, .low, .medium, .high, .userInitiated].map(\.rawValue))
    func testRunsWithExpectedPriority(priority: UInt8) async throws {
        let executor = TestExecutor()
        DeferredTask { }
            .run(executorPreference: executor, priority: TaskPriority(rawValue: priority))
        let receivedPriority = try await executor.receivedPriority.execute()
        #expect(receivedPriority == priority)
    }
}

@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
private final class TestExecutor: TaskExecutor, Sendable {
    init() { }
    let receivedPriority = SingleValueSubject<UInt8>()

    func enqueue(_ job: consuming ExecutorJob) {
        try? self.receivedPriority.send(job.priority.rawValue)
        job.runSynchronously(on: self.asUnownedTaskExecutor())
    }
}
#endif
