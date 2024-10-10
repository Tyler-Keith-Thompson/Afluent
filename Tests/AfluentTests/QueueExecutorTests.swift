//
//  QueueExecutorTasks.swift
//
//
//  Created by Annalise Mariottini on 10/10/24.
//

@testable import Afluent
import Foundation
import Testing

#if swift(>=6)
struct QueueExecutorTests {
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    @Test func runsOnExpectedQueue() async throws {
        await Task.detached(executorPreference: .mainQueue) {
            dispatchPrecondition(condition: .onQueue(.main))
        }.value

        await Task.detached(executorPreference: .globalQueue(qos: .background)) {
            dispatchPrecondition(condition: .onQueue(.global(qos: .background)))
        }.value

        let queue = DispatchQueue(label: "\(String(describing: Self.self))\(UUID().uuidString)")
        await Task.detached(executorPreference: .queue(queue)) {
            dispatchPrecondition(condition: .onQueue(queue))
        }.value
    }
}
#endif
