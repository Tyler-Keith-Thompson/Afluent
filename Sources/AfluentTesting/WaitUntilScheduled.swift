//
//  WaitUntilExecutionStarted.swift
//  Afluent
//
//  Created by Annalise Mariottini on 11/11/24.
//

import Afluent

extension Task where Failure == Error {
    /// Spawns a new task to run an asynchronous operation and waits until that task has started execution before returning.
    ///
    /// This method is useful when you want to guarantee that the spawned task has begun running before the caller continues, for example, to safely interact with shared state or resources initialized by the task.
    ///
    /// - Parameters:
    ///   - operation: An async throwing closure representing the operation to run in the spawned task.
    /// - Throws: Rethrows any error thrown by the operation during its execution.
    /// - Returns: The spawned `Task` running the specified operation.
    ///
    /// ## Example
    /// ```swift
    /// @Sendable func fetchData() async throws -> String {
    ///     // Simulates network request
    ///     try await Task.sleep(nanoseconds: 1_000_000_000)
    ///     return "Data"
    /// }
    ///
    /// func testWaitUntilExecutionStarted() async throws {
    ///     var hasStarted = false
    ///     let task = try await Task.waitUntilExecutionStarted {
    ///         hasStarted = true
    ///         return try await fetchData()
    ///     }
    ///     // At this point `hasStarted` is guaranteed to be true because the task has started.
    ///     assert(hasStarted)
    ///     let result = try await task.value
    ///     XCTAssertEqual(result, "Data")
    /// }
    /// ```
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
