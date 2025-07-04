//
//  WaitUntilCondition.swift
//  Afluent
//
//  Created by Annalise Mariottini on 11/9/24.
//

import Afluent

/// Waits asynchronously until the given condition evaluates to `true` or the specified timeout is reached.
/// 
/// This function repeatedly evaluates the condition and suspends the current task until the condition is met or the timeout expires.
/// 
/// - Parameters:
///   - condition: An asynchronous boolean condition to evaluate.
///   - timeout: The maximum duration to wait for the condition to become `true`.
/// 
/// - Throws: `TimeoutError.timedOut` if the timeout duration is exceeded before the condition becomes `true`.
/// 
/// ## Example
/// ```swift
/// var resourceIsReady = false
/// Task {
///     // Simulate resource initialization
///     try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
///     resourceIsReady = true
/// }
/// // Wait up to 5 seconds for the resource to become ready
/// try await wait(until: resourceIsReady, timeout: .seconds(5))
/// print("Resource is ready, proceeding with setup.")
/// ```
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func wait(
    until condition: @autoclosure @escaping @Sendable () async -> Bool, timeout: Duration
)
    async throws
{
    try await wait(until: await condition(), timeout: timeout, clock: ContinuousClock())
}

/// Waits asynchronously until the given condition evaluates to `true` or the specified timeout is reached,
/// using a custom clock to measure time.
///
/// This function repeatedly evaluates the condition and suspends the current task until the condition is met or the timeout expires.
/// Use this overload when you want to specify a custom clock instance (e.g., for testing or alternative time sources).
///
/// - Parameters:
///   - condition: An asynchronous boolean condition to evaluate.
///   - timeout: The maximum duration to wait for the condition to become `true`.
///   - clock: A clock instance used to measure the timeout duration.
/// 
/// - Throws: `TimeoutError.timedOut` if the timeout duration is exceeded before the condition becomes `true`.
///
/// ## Example
/// ```
/// let clock = TestClock()
/// var isDone = false
/// Task {
///     // Simulate some work completing later
///     try await clock.sleep(for: .seconds(2))
///     isDone = true
/// }
/// // This will wait for isDone or throw if 5 simulated seconds pass
/// try await wait(until: isDone, timeout: .seconds(5), clock: clock)
/// ```
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func wait<C: Clock>(
    until condition: @autoclosure @escaping @Sendable () async -> Bool, timeout: C.Duration,
    clock: C
) async throws {
    let start = clock.now
    let checkTimeout = {
        if start.duration(to: clock.now) >= timeout {
            throw TimeoutError.timedOut(duration: timeout)
        }
    }
    while await condition() == false {
        await Task.yield()
        try checkTimeout()
        try await clock.sleep(for: clock.minimumResolution)
    }
}

