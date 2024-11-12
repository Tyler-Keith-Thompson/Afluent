//
//  WaitUntilExecutionStarted.swift
//  Afluent
//
//  Created by Annalise Mariottini on 11/11/24.
//

import Afluent

extension Task where Failure == Error {
    /// Spawns a new Task to run some async operation and waits for that task to begin execution before proceeding.
    public static func waitUntilExecutionStarted(
        operation: @escaping @Sendable () async throws -> Success
    ) async throws -> Self {
        let sub = SingleValueSubject<Void>()
        let task = Task {
            try? sub.send()
            return try await operation()
        }
        try await sub.execute()
        return task
    }
}
