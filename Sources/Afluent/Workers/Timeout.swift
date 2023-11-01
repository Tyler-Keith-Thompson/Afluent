//
//  Timeout.swift
//  
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation
extension Workers {
    actor Timeout<Success: Sendable>: AsynchronousUnitOfWork {
        let state: TaskState<Success>
        var customError: Error?

        init<U: AsynchronousUnitOfWork>(upstream: U, duration: Measurement<UnitDuration>, error: Error?) where U.Success == Success {
            let nanosecondDelay = duration.converted(to: .nanoseconds).value
            customError = error
            state = TaskState.unsafeCreation()
            state.setOperation { [weak self] in
                guard let self else { throw CancellationError() }
                let timeoutTask = Task {
                    try await Task.sleep(nanoseconds: UInt64(nanosecondDelay))
                    upstream.cancel()
                }
                
                return try await Task { [weak self] in
                    guard let self else { throw CancellationError() }
                    do {
                        let result = try await upstream.execute()
                        timeoutTask.cancel()
                        return result
                    } catch {
                        timeoutTask.cancel()
                        throw await customError ?? error
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
    /// - Parameter customError: A custom error to throw if timeout occurs. If no value is supplied a `CancellationError` is thrown.
    /// - Returns: An asynchronous unit of work that includes the timeout behavior, encapsulating the operation's success or failure.
    public func timeout(_ duration: Measurement<UnitDuration>, customError: Error? = nil) -> some AsynchronousUnitOfWork<Success> {
        Workers.Timeout(upstream: self, duration: duration, error: customError)
    }
}
