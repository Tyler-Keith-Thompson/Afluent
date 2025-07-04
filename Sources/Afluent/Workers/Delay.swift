//
//  Delay.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation

extension Workers {
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    struct Delay<Upstream: AsynchronousUnitOfWork, Success: Sendable, C: Clock>:
        AsynchronousUnitOfWork
    where Upstream.Success == Success {
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
    /// Delays the emission of output from the upstream `AsynchronousUnitOfWork` by a specified duration.
    ///
    /// This operator suspends the emission of output for the given duration before returning the value.
    ///
    /// ## Discussion
    /// Delayed work is useful in scenarios such as throttling requests, implementing retry backoff strategies,
    /// or scheduling work to occur after a fixed interval. By delaying the emission, you can control timing
    /// behavior in asynchronous workflows in a straightforward and composable manner.
    ///
    /// ## Example
    /// ```swift
    /// let start = Date()
    /// let delayedTask = DeferredTask {
    ///     "Hello, world!"
    /// }.delay(for: .seconds(2))
    /// let result = try await delayedTask.execute()
    /// let elapsed = Date().timeIntervalSince(start)
    /// print("Result: \(result) after \(elapsed) seconds")
    /// ```
    ///
    /// - Parameter duration: The duration to delay the output.
    /// - Returns: An `AsynchronousUnitOfWork` that emits the upstream output after the specified delay.
    ///
    /// - Availability: macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0 and above.
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    public func delay(for duration: Duration) -> some AsynchronousUnitOfWork<Success> {
        Workers.Delay(upstream: self, clock: SuspendingClock(), duration: duration, tolerance: nil)
    }

    /// Delays the emission of output from the upstream `AsynchronousUnitOfWork` by a specified duration using a given clock.
    ///
    /// This operator suspends the emission of output for the specified duration according to the provided clock.
    ///
    /// ## Discussion
    /// Delaying work using a custom clock is beneficial when you need precise control over timing behavior,
    /// such as testing with test clocks or synchronizing work with specific time sources.
    /// Use this operator to implement retry backoff, throttling, or scheduled tasks that depend on a particular clock implementation.
    ///
    /// ## Example
    /// ```swift
    /// let start = Date()
    /// let clock = SuspendingClock()
    /// let delayedTask = DeferredTask {
    ///     "Delayed with custom clock"
    /// }.delay(for: .seconds(1), clock: clock, tolerance: .milliseconds(100))
    /// let result = try await delayedTask.execute()
    /// let elapsed = Date().timeIntervalSince(start)
    /// print("Result: \(result) after \(elapsed) seconds")
    /// ```
    ///
    /// - Parameters:
    ///   - duration: The duration to delay the output, conforming to the clock's associated `Duration` type.
    ///   - clock: The clock used for timekeeping. Defaults to `SuspendingClock()`.
    ///   - tolerance: An optional tolerance for the delay. Defaults to `nil`.
    /// - Returns: An `AsynchronousUnitOfWork` that emits the upstream output after the specified delay.
    ///
    /// - Availability: macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0 and above.
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    public func delay<C: Clock>(for duration: C.Duration, clock: C, tolerance: C.Duration? = nil)
        -> some AsynchronousUnitOfWork<Success>
    {
        Workers.Delay(upstream: self, clock: clock, duration: duration, tolerance: tolerance)
    }
}

