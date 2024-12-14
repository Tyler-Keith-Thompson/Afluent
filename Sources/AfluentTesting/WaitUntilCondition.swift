//
//  WaitUntilCondition.swift
//  Afluent
//
//  Created by Annalise Mariottini on 11/9/24.
//

import Afluent

/// Waits for some condition before proceeding, unless the specified timeout is reached, in which case an error is thrown.
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func wait(
    until condition: @autoclosure @escaping @Sendable () async -> Bool, timeout: Duration
)
    async throws
{
    try await wait(until: await condition(), timeout: timeout, clock: ContinuousClock())
}

/// Waits for some condition before proceeding, unless the specified timeout is reached, in which case an error is thrown.
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
