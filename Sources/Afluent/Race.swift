////
////  Race.swift
////
////
////  Created by Tyler Thompson on 6/30/24.
////
//
///// Executes two asynchronous tasks concurrently and returns the result of the first one that completes.
/////
///// - Parameters:
/////   - cancelAllOnWin: A boolean indicating whether the remaining tasks in the group should be cancelled if the race is won, defaults to true
/////   - firstTask: A closure representing the first asynchronous task to be executed.
/////   - secondTask: A closure representing the second asynchronous task to be executed.
///// - Returns: The result of the first task that completes.
///// - Throws: An error if any of the tasks throw an error.
/////
///// This function is useful when you have two potentially long-running operations and you want to proceed as soon as the first one completes. This is especially useful in scenarios where tasks may have variable completion times, and you want to optimize for the earliest result.
/////
///// ## Usage
/////
///// ```swift
///// do {
/////     let result = try await Race {
/////         // Simulate a task that takes 2 seconds
/////         try await Task.sleep(nanoseconds: 2_000_000_000)
/////         return "Task 1 Completed"
/////     } against: {
/////         // Simulate a task that takes 1 second
/////         try await Task.sleep(nanoseconds: 1_000_000_000)
/////         return "Task 2 Completed"
/////     }
/////     print("First completed task result: \(result)")
///// } catch {
/////     print("Error: \(error)")
///// }
///// ```
/////
///// ## Discussion
/////
///// The `Race` function uses `withThrowingTaskGroup` to run both tasks concurrently. It waits for the first task to complete and immediately returns its result. The remaining task is canceled to free up resources, ensuring that the system is not burdened by the second task that loses the race.
/////
///// This function is particularly useful in scenarios where you want to implement a timeout mechanism. For example, you can create a race between your primary task and a timeout task. If the primary task does not complete within the specified time, the timeout task will complete first, allowing you to handle the timeout situation appropriately.
/////
///// If `cancelAllOnWin` (defaulted to true) is true, cancellation of the losing task is handled automatically, preventing resource wastage. This is especially important in environments with limited resources or where task completion times are unpredictable.
/////
///// ## Important
///// A thrown error is considered to have won the race. Additionally, task groups don't guarantee parallelism, they guarantee concurrency. Consequently, while this is useful for lots of real world scenarios if you have strict parallelism requirements you may need to reach for GCD. [more information](https://forums.swift.org/t/taskgroup-and-parallelism/51039/1)
//public func Race<T: Sendable>(
//    cancelAllOnWin: Bool = true, _ firstTask: @Sendable () async throws -> T,
//    against tasks: (@Sendable () async throws -> T)...
//) async throws -> T {
//    try await withoutActuallyEscaping(firstTask) { firstTask in
//        try await withThrowingTaskGroup(of: T.self) { group in
//            group.addTask(operation: firstTask)
//            for task in tasks {
//                group.addTask(operation: task)
//            }
//            defer {
//                if cancelAllOnWin {
//                    group.cancelAll()
//                }
//            }
//            return try await group.next()!
//        }
//    }
//}
