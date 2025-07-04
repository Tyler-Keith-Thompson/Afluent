//
//  Timeout.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation

extension Workers {
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    struct Timeout<Upstream: AsynchronousUnitOfWork, Success: Sendable, C: Clock>:
        AsynchronousUnitOfWork
    where Upstream.Success == Success {
        let state = TaskState<Success>()
        let upstream: Upstream
        let customError: Error?
        let clock: C
        let duration: C.Duration
        let tolerance: C.Duration?

        init(
            upstream: Upstream, customError: Error?, clock: C, duration: C.Duration,
            tolerance: C.Duration?
        ) {
            self.upstream = upstream
            self.customError = customError
            self.clock = clock
            self.duration = duration
            self.tolerance = tolerance
        }

        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation {
                try await Race {
                    try await clock.sleep(
                        until: clock.now.advanced(by: duration), tolerance: tolerance)
                    throw customError ?? TimeoutError.timedOut(duration: duration)
                } against: {
                    try await upstream.execute()
                }
            }
        }
    }
}

extension AsynchronousUnitOfWork {
    /// Adds a timeout to this unit of work, cancelling it if it does not complete within the specified duration.
    ///
    /// ## Example
    /// ```swift
    /// try await DeferredTask { try await fetchData() }
    ///     .timeout(.seconds(5))
    ///     .execute()
    /// // Throws TimeoutError.timedOut if more than 5 seconds elapse
    /// ```
    ///
    /// - Parameter duration: The maximum allowed time for the operation (as a `Duration`).
    /// - Parameter customError: Optional error to throw if a timeout occurs. Defaults to `TimeoutError.timedOut`.
    /// - Returns: An `AsynchronousUnitOfWork` that throws if the duration is exceeded.
    /// - Throws: `TimeoutError` if the duration elapses before completion.
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    public func timeout(_ duration: Duration, customError: Error? = nil)
        -> some AsynchronousUnitOfWork<Success>
    {
        Workers.Timeout(
            upstream: self, customError: customError, clock: SuspendingClock(), duration: duration,
            tolerance: nil)
    }

    /// Adds a timeout to this unit of work, cancelling it if it does not complete in time, measured against the given clock.
    ///
    /// ## Example
    /// ```swift
    /// let clock = SuspendingClock()
    /// try await DeferredTask { try await fetchData() }
    ///     .timeout(.seconds(2), clock: clock, tolerance: .milliseconds(100))
    ///     .execute()
    /// ```
    ///
    /// - Parameter duration: The maximum allowed time for the operation (as a `Clock.Duration`).
    /// - Parameter clock: The clock used to measure timeouts (defaults to `SuspendingClock()`).
    /// - Parameter tolerance: Optional tolerance for the delay (defaults to `nil`).
    /// - Parameter customError: Optional error to throw if a timeout occurs. Defaults to `TimeoutError.timedOut`.
    /// - Returns: An `AsynchronousUnitOfWork` that throws if the duration is exceeded.
    /// - Throws: `TimeoutError` if the duration elapses before completion.
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    public func timeout<C: Clock>(
        _ duration: C.Duration, clock: C, tolerance: C.Duration? = nil, customError: Error? = nil
    ) -> some AsynchronousUnitOfWork<Success> {
        Workers.Timeout(
            upstream: self, customError: customError, clock: clock, duration: duration,
            tolerance: tolerance)
    }
}

