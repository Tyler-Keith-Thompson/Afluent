//
//  Timeout.swift
//  
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation
extension Workers {
    struct Timeout<Success: Sendable>: AsynchronousUnitOfWork {
        let state: TaskState<Success>

        init<U: AsynchronousUnitOfWork>(upstream: U, duration: Measurement<UnitDuration>) where U.Success == Success {
            let nanosecondDelay = duration.converted(to: .nanoseconds).value
            state = TaskState {
                let task = Task {
                    try await upstream.operation()
                }
                
                let timeoutTask = Task {
                    try await Task.sleep(nanoseconds: UInt64(nanosecondDelay))
                    task.cancel()
                }
                
                return try await Task {
                    do {
                        let result = try await task.value
                        timeoutTask.cancel()
                        return result
                    } catch {
                        timeoutTask.cancel()
                        throw error
                    }
                }.value
            }
        }
    }
}

extension AsynchronousUnitOfWork {
    /// Adds a timeout to the current asynchronous unit of work.
    ///
    /// If the operation does not complete within the specified duration, it will be terminated.
    ///
    /// - Parameter duration: The maximum duration the operation is allowed to take, represented as a `Measurement<UnitDuration>`.
    /// - Returns: An asynchronous unit of work that includes the timeout behavior, encapsulating the operation's success or failure.
    public func timeout(_ duration: Measurement<UnitDuration>) -> some AsynchronousUnitOfWork<Success> {
        Workers.Timeout(upstream: self, duration: duration)
    }
}
