//
//  Delay.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation

extension Workers {
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    struct Delay<Upstream: AsynchronousUnitOfWork, Success: Sendable, C: Clock>: AsynchronousUnitOfWork where Upstream.Success == Success {
        let state = TaskState<Success>()
        let upstream: Upstream
        let clock: C
        let duration: C.Duration
        let tolerance: C.Duration?

        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation {
                let val = try await upstream.operation()
                try await clock.sleep(until: clock.now.advanced(by: duration), tolerance: tolerance)
                return val
            }
        }
    }
}

extension AsynchronousUnitOfWork {
    /// Delays the emission of output from the upstream `AsynchronousUnitOfWork` by a specified duration using a given clock.
    ///
    /// - Parameters:
    ///   - duration: The duration to delay the output.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that emits the upstream output after the specified delay.
    ///
    /// - Availability: macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0 and above.
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    public func delay(for duration: Duration) -> some AsynchronousUnitOfWork<Success> {
        Workers.Delay(upstream: self, clock: SuspendingClock(), duration: duration, tolerance: nil)
    }

    /// Delays the emission of output from the upstream `AsynchronousUnitOfWork` by a specified duration using a given clock.
    ///
    /// - Parameters:
    ///   - duration: The duration to delay the output, conforming to the `C.Instant.Duration` type.
    ///   - clock: The clock used for timekeeping. Defaults to `SuspendingClock()`.
    ///   - tolerance: An optional tolerance for the delay. Defaults to `nil`.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that emits the upstream output after the specified delay.
    ///
    /// - Availability: macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0 and above.
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    public func delay<C: Clock>(for duration: C.Duration, clock: C, tolerance: C.Duration? = nil) -> some AsynchronousUnitOfWork<Success> {
        Workers.Delay(upstream: self, clock: clock, duration: duration, tolerance: tolerance)
    }
}
