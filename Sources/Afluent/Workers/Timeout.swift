//
//  Timeout.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation

extension Workers {
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    actor Timeout<Upstream: AsynchronousUnitOfWork, Success: Sendable, C: Clock>: AsynchronousUnitOfWork where Upstream.Success == Success {
        let state = TaskState<Success>()
        let upstream: Upstream
        var customError: Error?
        var timedOut = false
        let clock: C
        let duration: C.Duration
        let tolerance: C.Duration?

        init(upstream: Upstream, customError: Error?, clock: C, duration: C.Duration, tolerance: C.Duration?) {
            self.upstream = upstream
            self.customError = customError
            self.clock = clock
            self.duration = duration
            self.tolerance = tolerance
        }

        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation { [weak self] in
                guard let self else { throw CancellationError() }

                await self.reset()
                let timeoutTask = Task { [weak self] in
                    guard let self else { throw CancellationError() }
                    try await self.clock.sleep(until: self.clock.now.advanced(by: self.duration), tolerance: self.tolerance)
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
    /// - Parameter duration: The maximum duration the operation is allowed to take, represented as a `Duration`.
    /// - Parameter customError: A custom error to throw if timeout occurs. If no value is supplied a `CancellationError` is thrown.
    /// - Returns: An asynchronous unit of work that includes the timeout behavior, encapsulating the operation's success or failure.
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    public func timeout(_ duration: Duration, customError: Error? = nil) -> some AsynchronousUnitOfWork<Success> {
        Workers.Timeout(upstream: self, customError: customError, clock: SuspendingClock(), duration: duration, tolerance: nil)
    }

    /// Adds a timeout to the current asynchronous unit of work.
    ///
    /// If the operation does not complete within the specified duration, it will be terminated.
    ///
    /// - Parameter duration: The maximum duration the operation is allowed to take, represented as a `Clock.Duration`.
    /// - Parameter clock: The clock used for timekeeping. Defaults to `SuspendingClock()`.
    /// - Parameter tolerance: An optional tolerance for the delay. Defaults to `nil`.
    /// - Parameter customError: A custom error to throw if timeout occurs. If no value is supplied a `CancellationError` is thrown.
    /// - Returns: An asynchronous unit of work that includes the timeout behavior, encapsulating the operation's success or failure.
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    public func timeout<C: Clock>(_ duration: C.Duration, clock: C, tolerance: C.Duration? = nil, customError: Error? = nil) -> some AsynchronousUnitOfWork<Success> {
        Workers.Timeout(upstream: self, customError: customError, clock: clock, duration: duration, tolerance: tolerance)
    }
}
