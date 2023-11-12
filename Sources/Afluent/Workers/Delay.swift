//
//  Delay.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation

extension Workers {
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    struct Delay<Upstream: AsynchronousUnitOfWork, Success: Sendable>: AsynchronousUnitOfWork where Upstream.Success == Success {
        let state = TaskState<Success>()
        let upstream: Upstream
        let duration: Measurement<UnitDuration>
        
        func _operation() async throws -> Success {
            let val = try await upstream.operation()
            try await Task.sleep(nanoseconds: UInt64(duration.converted(to: .nanoseconds).value))
            return val
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
    public func delay(for duration: Measurement<UnitDuration>) -> some AsynchronousUnitOfWork<Success> {
        Workers.Delay(upstream: self, duration: duration)
    }
}
