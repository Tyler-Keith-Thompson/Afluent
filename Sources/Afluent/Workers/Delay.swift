//
//  Delay.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation

extension Workers {
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    struct Delay<Success: Sendable>: AsynchronousUnitOfWork {
        let state: TaskState<Success>

        init<U: AsynchronousUnitOfWork, C: Clock>(upstream: U, duration: C.Instant.Duration, tolerance: C.Instant.Duration?, clock: C) where U.Success == Success {
            state = TaskState {
                let val = try await upstream.operation()
                try await Task.sleep(for: duration, tolerance: tolerance, clock: clock)
                return val
            }
        }
    }
}

extension AsynchronousUnitOfWork {
    /// Delays the emission of output from the upstream `AsynchronousUnitOfWork` by a specified duration using a given clock.
    ///
    /// - Parameters:
    ///   - duration: The duration to delay the output, conforming to the `C.Instant.Duration` type.
    ///   - tolerance: An optional tolerance for the delay. Defaults to `nil`.
    ///   - clock: The clock used for timekeeping. Defaults to `ContinuousClock()`.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that emits the upstream output after the specified delay.
    ///
    /// - Availability: macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0 and above.
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    public func delay<C: Clock>(for duration: C.Instant.Duration, tolerance: C.Instant.Duration? = nil, clock: C = ContinuousClock()) -> some AsynchronousUnitOfWork<Success> {
        Workers.Delay(upstream: self, duration: duration, tolerance: tolerance, clock: clock)
    }
}
