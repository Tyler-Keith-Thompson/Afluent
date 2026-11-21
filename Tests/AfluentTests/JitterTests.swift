//
//  JitterTests.swift
//  Afluent
//

import Afluent
import AfluentTesting
import Clocks
import Foundation
import Generators
import Testing

struct JitterTests {
    // MARK: Any clock's duration

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(.timeLimit(.minutes(1))) func jitterWorksOnAClockWhoseDurationIsNotSwiftDuration()
        async throws
    {
        /// A whole number of ticks.
        struct Ticks: DurationProtocol, Hashable {
            var count: Int
            static var zero: Ticks { Ticks(count: 0) }
            static func + (lhs: Ticks, rhs: Ticks) -> Ticks { Ticks(count: lhs.count + rhs.count) }
            static func - (lhs: Ticks, rhs: Ticks) -> Ticks { Ticks(count: lhs.count - rhs.count) }
            static func < (lhs: Ticks, rhs: Ticks) -> Bool { lhs.count < rhs.count }
            static func / (lhs: Ticks, rhs: Int) -> Ticks { Ticks(count: lhs.count / rhs) }
            static func * (lhs: Ticks, rhs: Int) -> Ticks { Ticks(count: lhs.count * rhs) }
            static func / (lhs: Ticks, rhs: Ticks) -> Double { Double(lhs.count) / Double(rhs.count) }
        }
        struct TickInstant: InstantProtocol {
            var ticks: Int
            func advanced(by duration: Ticks) -> TickInstant { TickInstant(ticks: ticks + duration.count) }
            func duration(to other: TickInstant) -> Ticks { Ticks(count: other.ticks - ticks) }
            static func < (lhs: TickInstant, rhs: TickInstant) -> Bool { lhs.ticks < rhs.ticks }
        }
        /// Never suspends; records each wait it was asked for.
        final class TickClock: Clock, @unchecked Sendable {
            private let lock = NSLock()
            private var _waits = [Ticks]()
            var waits: [Ticks] { lock.withLock { _waits } }
            var now: TickInstant { TickInstant(ticks: 0) }
            var minimumResolution: Ticks { Ticks(count: 1) }
            func sleep(until deadline: TickInstant, tolerance: Ticks?) async throws {
                try Task.checkCancellation()
                lock.withLock { _waits.append(now.duration(to: deadline)) }
            }
        }
        func waits(_ jitter: Jitter) async throws -> [Ticks] {
            let clock = TickClock()
            let strategy = ExponentialBackoffStrategy<TickClock>(
                base: 2, maxDelay: Ticks(count: 1 << 30), jitter: jitter)
            for _ in 0 ..< 40 {
                _ = try await strategy.backoff(
                    clock: clock, durationUnit: { (n: Int) in Ticks(count: n * 1024) })
            }
            return clock.waits
        }
        // The delay without jitter: 2^n × 1024 ticks, capped at 2^30.
        let cap = Ticks(count: 1 << 30)
        let exact = (1 ... 40).map { n in min(Ticks(count: (1 << n) * 1024), cap) }
        let seed: UInt64 = 0x71C5

        let full = try await waits(.full(using: SplitMix64(seed: seed)))
        let fullAgain = try await waits(.full(using: SplitMix64(seed: seed)))
        let equal = try await waits(.equal(using: SplitMix64(seed: seed)))
        let equalAgain = try await waits(.equal(using: SplitMix64(seed: seed)))
        let decorrelated = try await waits(.decorrelated(using: SplitMix64(seed: seed)))
        let decorrelatedAgain = try await waits(.decorrelated(using: SplitMix64(seed: seed)))
        let none = try await waits(.none)
        let count = 40

        #expect(none == exact)
        #expect(full.count == count)
        #expect(full == fullAgain)
        #expect(equal == equalAgain)
        #expect(decorrelated == decorrelatedAgain)
        for (wait, delay) in zip(full, exact) {
            #expect(wait >= .zero && wait < delay, "seed \(seed)")
        }
        for (wait, delay) in zip(equal, exact) {
            #expect(wait >= delay / 2 && wait < delay, "seed \(seed)")
        }
        var previous: Ticks?
        for (wait, delay) in zip(decorrelated, exact) {
            #expect(wait >= delay && wait <= cap, "seed \(seed)")
            if let previous, wait != delay { #expect(wait < previous * 3, "seed \(seed)") }
            previous = wait
        }
        #expect(Set(full).count > 1, "seed \(seed)")
        #expect(full != exact, "seed \(seed)")
        #expect(decorrelated != exact, "seed \(seed)")
    }

    // MARK: ExponentialBackoffStrategy

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(.timeLimit(.minutes(1))) func fullJitterOnABackoffWaitsUnderEachDelayAndReproducesFromTheSeed()
        async throws
    {
        func waits(_ jitter: Jitter) async throws -> [Duration] {
            let clock = ImmediateClock<Duration>()
            let strategy = ExponentialBackoffStrategy<ImmediateClock<Duration>>(
                base: 2, maxDelay: .seconds(60), jitter: jitter)
            var waits = [Duration]()
            for _ in 0 ..< 20 {
                let start = clock.now
                _ = try await strategy.backoff(clock: clock, durationUnit: { (n: Int) in .seconds(n) })
                waits.append(start.duration(to: clock.now))
            }
            return waits
        }
        let exact = (1 ... 20).map { n -> Duration in n < 6 ? .seconds(1 << n) : .seconds(60) }
        let seed: UInt64 = 0xF011

        let first = try await waits(.full(using: SplitMix64(seed: seed)))
        let second = try await waits(.full(using: SplitMix64(seed: seed)))

        #expect(first == second, "seed \(seed)")
        for (wait, delay) in zip(first, exact) {
            #expect(wait >= .zero && wait < delay, "seed \(seed)")
        }
        #expect(Set(first).count > 1, "seed \(seed)")
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(.timeLimit(.minutes(1)))
    func equalJitterOnABackoffWaitsInTheUpperHalfOfEachDelayAndReproducesFromTheSeed() async throws {
        func waits(_ jitter: Jitter) async throws -> [Duration] {
            let clock = ImmediateClock<Duration>()
            let strategy = ExponentialBackoffStrategy<ImmediateClock<Duration>>(
                base: 2, maxDelay: .seconds(60), jitter: jitter)
            var waits = [Duration]()
            for _ in 0 ..< 20 {
                let start = clock.now
                _ = try await strategy.backoff(clock: clock, durationUnit: { (n: Int) in .seconds(n) })
                waits.append(start.duration(to: clock.now))
            }
            return waits
        }
        let exact = (1 ... 20).map { n -> Duration in n < 6 ? .seconds(1 << n) : .seconds(60) }
        let seed: UInt64 = 0xE0A1

        let first = try await waits(.equal(using: SplitMix64(seed: seed)))
        let second = try await waits(.equal(using: SplitMix64(seed: seed)))

        #expect(first == second, "seed \(seed)")
        for (wait, delay) in zip(first, exact) {
            #expect(wait >= delay / 2 && wait < delay, "seed \(seed)")
        }
        #expect(Set(first).count > 1, "seed \(seed)")
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(.timeLimit(.minutes(1)))
    func decorrelatedJitterOnABackoffWaitsFromTheDelayToThreeTimesTheLastWaitCappedAtMaxDelay()
        async throws
    {
        func waits(_ jitter: Jitter) async throws -> [Duration] {
            let clock = ImmediateClock<Duration>()
            let strategy = ExponentialBackoffStrategy<ImmediateClock<Duration>>(
                base: 2, maxDelay: .seconds(60), jitter: jitter)
            var waits = [Duration]()
            for _ in 0 ..< 20 {
                let start = clock.now
                _ = try await strategy.backoff(clock: clock, durationUnit: { (n: Int) in .seconds(n) })
                waits.append(start.duration(to: clock.now))
            }
            return waits
        }
        let exact = (1 ... 20).map { n -> Duration in n < 6 ? .seconds(1 << n) : .seconds(60) }
        let cap: Duration = .seconds(60)
        let seed: UInt64 = 0xDEC0

        let first = try await waits(.decorrelated(using: SplitMix64(seed: seed)))
        let second = try await waits(.decorrelated(using: SplitMix64(seed: seed)))

        #expect(first == second, "seed \(seed)")
        #expect(first.first == exact.first, "seed \(seed)")
        var previous: Duration?
        for (wait, delay) in zip(first, exact) {
            #expect(wait >= delay && wait <= cap, "seed \(seed)")
            if let previous, wait != delay { #expect(wait < previous * 3, "seed \(seed)") }
            previous = wait
        }
        #expect(first != exact, "seed \(seed)")
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(.timeLimit(.minutes(1))) func resettingABackoffMakesDecorrelatedJitterForgetItsLastWait()
        async throws
    {
        /// Always draws the largest value.
        struct Ones: RandomNumberGenerator, Sendable {
            mutating func next() -> UInt64 { .max }
        }
        let clock = ImmediateClock<Duration>()
        let strategy = ExponentialBackoffStrategy<ImmediateClock<Duration>>(
            base: 2, jitter: .decorrelated(using: Ones()))
        let expectedFirst: Duration = .seconds(2)
        let secondFloor: Duration = .seconds(4)
        let secondCeiling: Duration = .seconds(6)

        var waits = [Duration]()
        for attempt in 0 ..< 3 {
            if attempt == 2 { await strategy.reset() }
            let start = clock.now
            _ = try await strategy.backoff(clock: clock, durationUnit: { (n: Int) in .seconds(n) })
            waits.append(start.duration(to: clock.now))
        }

        // No previous wait: exactly the delay. Then up to three times it. After the reset, exactly again.
        #expect(waits[0] == expectedFirst)
        #expect(waits[1] > secondFloor && waits[1] < secondCeiling)
        #expect(waits[2] == expectedFirst)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(.timeLimit(.minutes(1))) func cancellingDuringAJitteredBackoffEndsItAtOnce() async throws {
        let clock = TrackedTestClock()
        let strategy = ExponentialBackoffStrategy<TrackedTestClock>(
            base: 2, jitter: .equal(using: SplitMix64(seed: 0xCA9C)))
        let expectedSleepers = 0

        let backingOff = Task {
            try await strategy.backoff(clock: clock, durationUnit: { (n: Int) in .seconds(n) })
        }
        try await wait(until: clock.sleepingCount == 1, timeout: .seconds(2))
        backingOff.cancel()

        await #expect(throws: CancellationError.self) { try await backingOff.value }
        #expect(clock.sleepingCount == expectedSleepers)
    }

    // MARK: TimerSequence

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1))) func fullJitterOnATimerTicksAnywhereInEachPeriodAndReproducesFromTheSeed()
        async throws
    {
        let interval: Duration = .seconds(10)
        /// How far into its period each tick fell.
        func offsets(_ jitter: Jitter) async -> [Duration] {
            let clock = ImmediateClock<Duration>()
            let start = clock.now
            var iterator = TimerSequence.publish(every: interval, clock: clock, jitter: jitter)
                .makeAsyncIterator()
            var offsets = [Duration]()
            for period in 0 ..< 50 {
                guard let tick = await iterator.next() else { break }
                offsets.append(start.duration(to: tick) - interval * period)
            }
            return offsets
        }
        let seed: UInt64 = 0x7F11
        let count = 50

        let first = await offsets(.full(using: SplitMix64(seed: seed)))
        let second = await offsets(.full(using: SplitMix64(seed: seed)))

        #expect(first.count == count)
        #expect(first == second, "seed \(seed)")
        for offset in first {
            #expect(offset >= .zero && offset < interval, "seed \(seed)")
        }
        #expect(Set(first).count > 1, "seed \(seed)")
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1)))
    func equalJitterOnATimerTicksInTheSecondHalfOfEachPeriodAndReproducesFromTheSeed() async throws {
        let interval: Duration = .seconds(10)
        /// How far into its period each tick fell.
        func offsets(_ jitter: Jitter) async -> [Duration] {
            let clock = ImmediateClock<Duration>()
            let start = clock.now
            var iterator = TimerSequence.publish(every: interval, clock: clock, jitter: jitter)
                .makeAsyncIterator()
            var offsets = [Duration]()
            for period in 0 ..< 50 {
                guard let tick = await iterator.next() else { break }
                offsets.append(start.duration(to: tick) - interval * period)
            }
            return offsets
        }
        let seed: UInt64 = 0x7E0A
        let count = 50

        let first = await offsets(.equal(using: SplitMix64(seed: seed)))
        let second = await offsets(.equal(using: SplitMix64(seed: seed)))

        #expect(first.count == count)
        #expect(first == second, "seed \(seed)")
        for offset in first {
            #expect(offset >= interval / 2 && offset < interval, "seed \(seed)")
        }
        #expect(Set(first).count > 1, "seed \(seed)")
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1))) func decorrelatedJitterOnATimerTicksExactlyOnSchedule() async throws {
        let interval: Duration = .seconds(10)
        let clock = ImmediateClock<Duration>()
        let start = clock.now
        let seed: UInt64 = 0x7DEC
        var iterator = TimerSequence.publish(
            every: interval, clock: clock, jitter: .decorrelated(using: SplitMix64(seed: seed))
        ).makeAsyncIterator()
        let expected = (1 ... 50).map { interval * $0 }

        var ticks = [Duration]()
        for _ in 0 ..< 50 {
            guard let tick = await iterator.next() else { break }
            ticks.append(start.duration(to: tick))
        }

        #expect(ticks == expected, "seed \(seed)")
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1))) func cancellingDuringAJitteredTimerWaitEndsItAtOnce() async throws {
        let clock = TrackedTestClock()
        let timer = TimerSequence.publish(
            every: .seconds(10), clock: clock, jitter: .equal(using: SplitMix64(seed: 0x7CA9)))
        let expectedSleepers = 0

        let ticking = Task {
            var iterator = timer.makeAsyncIterator()
            return await iterator.next()
        }
        try await wait(until: clock.sleepingCount == 1, timeout: .seconds(2))
        ticking.cancel()
        let tick = await ticking.value

        #expect(tick == nil)
        #expect(clock.sleepingCount == expectedSleepers)
    }

    // MARK: AsynchronousUnitOfWork.delay

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1))) func fullJitterOnADelayedUnitOfWorkWaitsUnderTheDelayAndReproducesFromTheSeed()
        async throws
    {
        let duration: Duration = .seconds(10)
        func waits(_ jitter: Jitter) async throws -> [Duration] {
            let clock = ImmediateClock<Duration>()
            var waits = [Duration]()
            for _ in 0 ..< 20 {
                let start = clock.now
                try await DeferredTask {}.delay(for: duration, clock: clock, jitter: jitter).execute()
                waits.append(start.duration(to: clock.now))
            }
            return waits
        }
        let seed: UInt64 = 0xDF11

        let first = try await waits(.full(using: SplitMix64(seed: seed)))
        let second = try await waits(.full(using: SplitMix64(seed: seed)))

        #expect(first == second, "seed \(seed)")
        for wait in first {
            #expect(wait >= .zero && wait < duration, "seed \(seed)")
        }
        #expect(Set(first).count > 1, "seed \(seed)")
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1)))
    func equalJitterOnADelayedUnitOfWorkWaitsInTheUpperHalfOfTheDelayAndReproducesFromTheSeed()
        async throws
    {
        let duration: Duration = .seconds(10)
        func waits(_ jitter: Jitter) async throws -> [Duration] {
            let clock = ImmediateClock<Duration>()
            var waits = [Duration]()
            for _ in 0 ..< 20 {
                let start = clock.now
                try await DeferredTask {}.delay(for: duration, clock: clock, jitter: jitter).execute()
                waits.append(start.duration(to: clock.now))
            }
            return waits
        }
        let seed: UInt64 = 0xDE0A

        let first = try await waits(.equal(using: SplitMix64(seed: seed)))
        let second = try await waits(.equal(using: SplitMix64(seed: seed)))

        #expect(first == second, "seed \(seed)")
        for wait in first {
            #expect(wait >= duration / 2 && wait < duration, "seed \(seed)")
        }
        #expect(Set(first).count > 1, "seed \(seed)")
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1)))
    func decorrelatedJitterOnADelayedUnitOfWorkWaitsFromTheDelayToThreeTimesIt() async throws {
        let duration: Duration = .seconds(10)
        func waits(_ jitter: Jitter) async throws -> [Duration] {
            let clock = ImmediateClock<Duration>()
            var waits = [Duration]()
            for _ in 0 ..< 20 {
                let start = clock.now
                try await DeferredTask {}.delay(for: duration, clock: clock, jitter: jitter).execute()
                waits.append(start.duration(to: clock.now))
            }
            return waits
        }
        let limit: Duration = .seconds(30)
        let seed: UInt64 = 0xDDEC

        let first = try await waits(.decorrelated(using: SplitMix64(seed: seed)))
        let second = try await waits(.decorrelated(using: SplitMix64(seed: seed)))

        #expect(first == second, "seed \(seed)")
        #expect(first.first == duration, "seed \(seed)")
        var previous: Duration?
        for wait in first {
            #expect(wait >= duration && wait <= limit, "seed \(seed)")
            if let previous, wait != duration { #expect(wait < previous * 3, "seed \(seed)") }
            previous = wait
        }
        #expect(Set(first).count > 1, "seed \(seed)")
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1))) func cancellingDuringAJitteredUnitOfWorkDelayEndsItAtOnce()
        async throws
    {
        let clock = TrackedTestClock()
        let expectedSleepers = 0

        let delaying = Task {
            try await DeferredTask { 1 }
                .delay(
                    for: .seconds(10), clock: clock,
                    jitter: .decorrelated(using: SplitMix64(seed: 0xDCA9))
                )
                .execute()
        }
        try await wait(until: clock.sleepingCount == 1, timeout: .seconds(2))
        delaying.cancel()

        await #expect(throws: CancellationError.self) { try await delaying.value }
        #expect(clock.sleepingCount == expectedSleepers)
    }

    // MARK: AsyncSequence.delay

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1))) func fullJitterOnADelayedSequenceWaitsUnderTheDelayAndReproducesFromTheSeed()
        async throws
    {
        /// Never suspends and never moves; records each wait it was asked for.
        final class RecordingClock: Clock, @unchecked Sendable {
            private let lock = NSLock()
            private var _waits = [Duration]()
            let now = ContinuousClock.now
            var waits: [Duration] { lock.withLock { _waits } }
            var minimumResolution: Duration { .zero }
            func sleep(until deadline: ContinuousClock.Instant, tolerance: Duration?) async throws {
                try Task.checkCancellation()
                lock.withLock { _waits.append(now.duration(to: deadline)) }
            }
        }
        let interval: Duration = .seconds(10)
        func waits(_ jitter: Jitter) async throws -> [Duration] {
            let clock = RecordingClock()
            for try await _ in Array(1 ... 20).async.delay(for: interval, clock: clock, jitter: jitter) {}
            return clock.waits
        }
        let seed: UInt64 = 0x5F11
        let count = 20

        let first = try await waits(.full(using: SplitMix64(seed: seed)))
        let second = try await waits(.full(using: SplitMix64(seed: seed)))

        #expect(first.count == count)
        #expect(first == second, "seed \(seed)")
        for wait in first {
            #expect(wait >= .zero && wait < interval, "seed \(seed)")
        }
        #expect(Set(first).count > 1, "seed \(seed)")
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1)))
    func equalJitterOnADelayedSequenceWaitsInTheUpperHalfOfTheDelayAndReproducesFromTheSeed()
        async throws
    {
        /// Never suspends and never moves; records each wait it was asked for.
        final class RecordingClock: Clock, @unchecked Sendable {
            private let lock = NSLock()
            private var _waits = [Duration]()
            let now = ContinuousClock.now
            var waits: [Duration] { lock.withLock { _waits } }
            var minimumResolution: Duration { .zero }
            func sleep(until deadline: ContinuousClock.Instant, tolerance: Duration?) async throws {
                try Task.checkCancellation()
                lock.withLock { _waits.append(now.duration(to: deadline)) }
            }
        }
        let interval: Duration = .seconds(10)
        func waits(_ jitter: Jitter) async throws -> [Duration] {
            let clock = RecordingClock()
            for try await _ in Array(1 ... 20).async.delay(for: interval, clock: clock, jitter: jitter) {}
            return clock.waits
        }
        let seed: UInt64 = 0x5E0A
        let count = 20

        let first = try await waits(.equal(using: SplitMix64(seed: seed)))
        let second = try await waits(.equal(using: SplitMix64(seed: seed)))

        #expect(first.count == count)
        #expect(first == second, "seed \(seed)")
        for wait in first {
            #expect(wait >= interval / 2 && wait < interval, "seed \(seed)")
        }
        #expect(Set(first).count > 1, "seed \(seed)")
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1)))
    func decorrelatedJitterOnADelayedSequenceWaitsFromTheDelayToThreeTimesIt() async throws {
        /// Never suspends and never moves; records each wait it was asked for.
        final class RecordingClock: Clock, @unchecked Sendable {
            private let lock = NSLock()
            private var _waits = [Duration]()
            let now = ContinuousClock.now
            var waits: [Duration] { lock.withLock { _waits } }
            var minimumResolution: Duration { .zero }
            func sleep(until deadline: ContinuousClock.Instant, tolerance: Duration?) async throws {
                try Task.checkCancellation()
                lock.withLock { _waits.append(now.duration(to: deadline)) }
            }
        }
        let interval: Duration = .seconds(10)
        func waits(_ jitter: Jitter) async throws -> [Duration] {
            let clock = RecordingClock()
            for try await _ in Array(1 ... 20).async.delay(for: interval, clock: clock, jitter: jitter) {}
            return clock.waits
        }
        let limit: Duration = .seconds(30)
        let seed: UInt64 = 0x5DEC
        let count = 20

        let first = try await waits(.decorrelated(using: SplitMix64(seed: seed)))
        let second = try await waits(.decorrelated(using: SplitMix64(seed: seed)))

        #expect(first.count == count)
        #expect(first == second, "seed \(seed)")
        #expect(first.first == interval, "seed \(seed)")
        var previous: Duration?
        for wait in first {
            #expect(wait >= interval && wait <= limit, "seed \(seed)")
            if let previous, wait != interval { #expect(wait < previous * 3, "seed \(seed)") }
            previous = wait
        }
        #expect(Set(first).count > 1, "seed \(seed)")
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1))) func cancellingDuringAJitteredSequenceDelayEndsItAtOnce()
        async throws
    {
        let clock = TrackedTestClock()
        let delayed = [1].async.delay(
            for: .seconds(10), clock: clock, jitter: .equal(using: SplitMix64(seed: 0x5CA9)))
        let expectedSleepers = 0

        let delaying = Task {
            for try await _ in delayed {}
        }
        try await wait(until: clock.sleepingCount == 1, timeout: .seconds(2))
        delaying.cancel()

        await #expect(throws: CancellationError.self) { try await delaying.value }
        #expect(clock.sleepingCount == expectedSleepers)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1))) func fullJitterOnAnOddIntegerDurationReachesEveryValue() async throws {
        struct Ticks: DurationProtocol, Hashable {
            var count: Int
            static var zero: Ticks { Ticks(count: 0) }
            static func + (lhs: Ticks, rhs: Ticks) -> Ticks { Ticks(count: lhs.count + rhs.count) }
            static func - (lhs: Ticks, rhs: Ticks) -> Ticks { Ticks(count: lhs.count - rhs.count) }
            static func < (lhs: Ticks, rhs: Ticks) -> Bool { lhs.count < rhs.count }
            static func / (lhs: Ticks, rhs: Int) -> Ticks { Ticks(count: lhs.count / rhs) }
            static func * (lhs: Ticks, rhs: Int) -> Ticks { Ticks(count: lhs.count * rhs) }
            static func / (lhs: Ticks, rhs: Ticks) -> Double { Double(lhs.count) / Double(rhs.count) }
        }
        struct TickInstant: InstantProtocol {
            var ticks: Int
            func advanced(by duration: Ticks) -> TickInstant { TickInstant(ticks: ticks + duration.count) }
            func duration(to other: TickInstant) -> Ticks { Ticks(count: other.ticks - ticks) }
            static func < (lhs: TickInstant, rhs: TickInstant) -> Bool { lhs.ticks < rhs.ticks }
        }
        /// Never suspends; records each wait it was asked for.
        final class TickClock: Clock, @unchecked Sendable {
            private let lock = NSLock()
            private var _waits = [Ticks]()
            var waits: [Ticks] { lock.withLock { _waits } }
            var now: TickInstant { TickInstant(ticks: 0) }
            var minimumResolution: Ticks { Ticks(count: 1) }
            func sleep(until deadline: TickInstant, tolerance: Ticks?) async throws {
                try Task.checkCancellation()
                lock.withLock { _waits.append(now.duration(to: deadline)) }
            }
        }
        let clock = TickClock()
        let seed: UInt64 = 0x0DD
        let jitter = Jitter.full(using: SplitMix64(seed: seed))
        let expected = Set((0 ..< 7).map { Ticks(count: $0) })

        for _ in 0 ..< 500 {
            try await DeferredTask { }
                .delay(for: Ticks(count: 7), clock: clock, jitter: jitter)
                .execute()
        }

        #expect(Set(clock.waits) == expected, "seed \(seed)")
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(.timeLimit(.minutes(1))) func decorrelatedJitterOnAHugeIntegerDelayDoesNotOverflow() async throws {
        struct Ticks: DurationProtocol, Hashable {
            var count: Int
            static var zero: Ticks { Ticks(count: 0) }
            static func + (lhs: Ticks, rhs: Ticks) -> Ticks { Ticks(count: lhs.count + rhs.count) }
            static func - (lhs: Ticks, rhs: Ticks) -> Ticks { Ticks(count: lhs.count - rhs.count) }
            static func < (lhs: Ticks, rhs: Ticks) -> Bool { lhs.count < rhs.count }
            static func / (lhs: Ticks, rhs: Int) -> Ticks { Ticks(count: lhs.count / rhs) }
            static func * (lhs: Ticks, rhs: Int) -> Ticks { Ticks(count: lhs.count * rhs) }
            static func / (lhs: Ticks, rhs: Ticks) -> Double { Double(lhs.count) / Double(rhs.count) }
        }
        struct TickInstant: InstantProtocol {
            var ticks: Int
            func advanced(by duration: Ticks) -> TickInstant { TickInstant(ticks: ticks + duration.count) }
            func duration(to other: TickInstant) -> Ticks { Ticks(count: other.ticks - ticks) }
            static func < (lhs: TickInstant, rhs: TickInstant) -> Bool { lhs.ticks < rhs.ticks }
        }
        /// Never suspends; records each wait it was asked for.
        final class TickClock: Clock, @unchecked Sendable {
            private let lock = NSLock()
            private var _waits = [Ticks]()
            var waits: [Ticks] { lock.withLock { _waits } }
            var now: TickInstant { TickInstant(ticks: 0) }
            var minimumResolution: Ticks { Ticks(count: 1) }
            func sleep(until deadline: TickInstant, tolerance: Ticks?) async throws {
                try Task.checkCancellation()
                lock.withLock { _waits.append(now.duration(to: deadline)) }
            }
        }
        let clock = TickClock()
        let seed: UInt64 = 0xB16
        // Three times this is past Int.max; only the waits themselves need to fit.
        let duration = Ticks(count: Int.max / 2)
        let jitter = Jitter.decorrelated(using: SplitMix64(seed: seed))
        let expected: [Ticks] = [duration]

        try await DeferredTask { }
            .delay(for: duration, clock: clock, jitter: jitter)
            .execute()

        #expect(clock.waits == expected, "seed \(seed)")
    }
}
