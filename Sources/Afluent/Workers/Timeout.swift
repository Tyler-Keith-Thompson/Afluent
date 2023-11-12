//
//  Timeout.swift
//  
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation
extension Workers {
    actor Timeout<Upstream: AsynchronousUnitOfWork, Success: Sendable>: AsynchronousUnitOfWork where Upstream.Success == Success {
        let state = TaskState<Success>()
        let upstream: Upstream
        var customError: Error?
        var timedOut = false
        let duration: Measurement<UnitDuration>

        init(upstream: Upstream, duration: Measurement<UnitDuration>, error: Error?) {
            self.upstream = upstream
            self.duration = duration
            customError = error
        }
        
        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation { [weak self] in
                guard let self else { throw CancellationError() }

                await self.reset()
                let timeoutTask = Task { [weak self] in
                    guard let self else { throw CancellationError() }
                    try await Task.sleep(nanoseconds: UInt64(self.duration.converted(to: .nanoseconds).value))
                    await self.timeout()
                    self.upstream.cancel()
                }
                
                return try await Task { [weak self] in
                    guard let self else { throw CancellationError() }
                    do {
                        let result = try await self.upstream.execute()
                        timeoutTask.cancel()
                        return result
                    } catch {
                        timeoutTask.cancel()
                        if await self.timedOut {
                            throw await self.customError ?? CancellationError()
                        } else {
                            throw error
                        }
                    }
                }.value
            }
        }
        
        func reset() {
            timedOut = false
        }
        
        func timeout() {
            timedOut = true
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
