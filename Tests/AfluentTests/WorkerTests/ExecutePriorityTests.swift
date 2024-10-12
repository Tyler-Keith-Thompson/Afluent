//
//  ExecutePriorityTests.swift
//  Afluent
//
//  Created by Annalise Mariottini on 10/10/24.
//

import Afluent
import Foundation
@_spi(Experimental) import Testing

@Suite(.serialized)
struct ExecutePriorityTests {
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(.serialized, arguments: [TaskPriority.background, .low, .medium, .high, .userInitiated])
    func executesWithExpectedPriority(priority: TaskPriority) async throws {
        let completed = SingleValueSubject<Void>()

        // With structured concurrency, awaiting a value will cause that work to be performed with at least the priority of the current context
        // Thus Task.currentPriority is not always the priority passed during Task creation
        // Task.basePriority on the other hand, is unchanged once the Task is created
        // References:
        // https://forums.swift.org/t/taskpriority-of-task-groups-child-tasks/74877/4
        // https://forums.swift.org/t/task-priority-elevation-for-task-groups-and-async-let/61100

        let expectedCurrentPriority = max(Task.currentPriority, priority)

        try await DeferredTask { }
            .handleEvents(receiveOutput: {
                #expect(Task.basePriority == priority)
                #expect(Task.currentPriority == expectedCurrentPriority)
                try completed.send()
            })
            .execute(priority: priority)

        try await completed.execute()
    }

    @Test(.serialized, arguments: [TaskPriority.background, .low, .medium, .high, .userInitiated])
    func runsWithExpectedPriority(priority: TaskPriority) async throws {
        let completed = SingleValueSubject<Void>()

        DeferredTask { }
            .handleEvents(receiveOutput: {
                #expect(Task.currentPriority == priority)
                try completed.send()
            })
            .run(priority: priority)

        try await completed.execute()
    }

    @Test(.serialized, arguments: [TaskPriority.background, .low, .medium, .high, .userInitiated])
    func subscribesWithExpectedPriority(priority: TaskPriority) async throws {
        let completed = SingleValueSubject<Void>()

        let subscription = DeferredTask { }
            .handleEvents(receiveOutput: { _ in
                #expect(Task.currentPriority == priority)
                try completed.send()
            })
            .subscribe(priority: priority)

        noop(subscription)

        try await completed.execute()
    }

    private func noop(_ any: Any) { }
}
