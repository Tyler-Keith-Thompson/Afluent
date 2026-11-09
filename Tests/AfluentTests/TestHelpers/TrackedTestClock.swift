//
//  TrackedTestClock.swift
//  Afluent
//

import AfluentTesting
import Clocks
import ConcurrencyExtras
import Foundation

/// A manually advanced test clock that knows exactly how many tasks are sleeping on it.
///
/// It behaves like swift-clocks' `TestClock` (same `Instant` type, same rules for when `advance` wakes a sleep),
/// but keeps its own list of registered sleeps. Like a real clock, a sleep whose deadline has already been reached
/// returns at once. Otherwise a sleep that registers just after an advance to exactly its deadline would wait for
/// an advance that never comes. `TestClock.advance(by:)` only yields a fixed
/// number of times for sleepers to register; under load a sleep can register after the advance, so its deadline
/// is computed from the advanced time and it never fires (or it returns at once with the wrong time). Use
/// ``advance(by:whenSleeping:)`` right after starting work that sleeps, so time only moves once every expected
/// sleep is registered.
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
final class TrackedTestClock: Clock, @unchecked Sendable {
    typealias Duration = Swift.Duration
    typealias Instant = TestClock<Duration>.Instant

    private let lock = NSLock()
    private var _now = Instant()
    private struct Suspension {
        let id: UUID
        let deadline: Instant
        let continuation: AsyncThrowingStream<Never, Error>.Continuation
    }
    private var suspensions = [Suspension]()

    private func sync<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    var now: Instant { sync { _now } }
    var minimumResolution: Duration { .zero }

    /// The number of tasks currently sleeping on this clock. A sleep counts once it is registered, so an advance
    /// made after seeing it will wake it.
    var sleepingCount: Int { sync { suspensions.count } }

    func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws {
        try Task.checkCancellation()
        let id = UUID()
        do {
            let stream: AsyncThrowingStream<Never, Error>? = sync {
                guard deadline > _now else { return nil }
                return AsyncThrowingStream { continuation in
                    suspensions.append(
                        Suspension(id: id, deadline: deadline, continuation: continuation))
                }
            }
            guard let stream else { return }
            for try await _ in stream {}
            try Task.checkCancellation()
        } catch is CancellationError {
            sync { suspensions.removeAll { $0.id == id } }
            throw CancellationError()
        }
    }

    /// Advances without waiting for sleepers, for when the test knows none should be affected or they are
    /// already in place.
    func advance(by duration: Duration) async {
        let target = now.advanced(by: duration)
        while true {
            await Task.megaYield()
            let next: AsyncThrowingStream<Never, Error>.Continuation? = sync {
                suspensions.sort { $0.deadline < $1.deadline }
                guard let first = suspensions.first, first.deadline <= target else {
                    _now = target
                    return nil
                }
                _now = first.deadline
                suspensions.removeFirst()
                return first.continuation
            }
            guard let next else { break }
            next.finish()
        }
        await Task.megaYield()
    }

    /// Waits until at least `count` tasks are sleeping on this clock, then advances it.
    func advance(
        by duration: Duration, whenSleeping count: Int, timeout: Duration = .seconds(2)
    ) async throws {
        try await wait(until: self.sleepingCount >= count, timeout: timeout)
        await advance(by: duration)
    }
}
