//
//  TrackedTestClock.swift
//  Afluent
//

import AfluentTesting
import Atomics
import Clocks

/// A `TestClock` that knows how many tasks are sleeping on it.
///
/// `TestClock.advance(by:)` only yields a fixed number of times for sleepers to register. Under load a sleep
/// can register after the advance, so its deadline is computed from the advanced time and it never fires (or
/// it returns at once with the wrong time). Use ``advance(by:whenSleeping:)`` right after starting work that
/// sleeps, so time only moves once every expected sleep is in place.
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
final class TrackedTestClock: Clock {
    typealias Duration = Swift.Duration
    typealias Instant = TestClock<Duration>.Instant

    private let base = TestClock()
    private let sleeping = ManagedAtomic(0)

    var now: Instant { base.now }
    var minimumResolution: Duration { base.minimumResolution }

    /// The number of tasks currently sleeping on this clock.
    var sleepingCount: Int { sleeping.load(ordering: .sequentiallyConsistent) }

    func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws {
        sleeping.wrappingIncrement(ordering: .sequentiallyConsistent)
        defer { sleeping.wrappingDecrement(ordering: .sequentiallyConsistent) }
        try await base.sleep(until: deadline, tolerance: tolerance)
    }

    /// Advances without waiting for sleepers, for when the test already knows they are in place.
    func advance(by duration: Duration) async {
        await base.advance(by: duration)
    }

    /// Waits until at least `count` tasks are sleeping on this clock, then advances it.
    func advance(
        by duration: Duration, whenSleeping count: Int, timeout: Duration = .seconds(2)
    ) async throws {
        try await wait(until: self.sleepingCount >= count, timeout: timeout)
        await base.advance(by: duration)
    }
}
