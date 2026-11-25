//
//  ExponentialBackoffInitialDelayTests.swift
//  Afluent
//

import Afluent
import AfluentTesting
import Clocks
import Foundation
import Generators
import PropertyBased
import Testing

struct ExponentialBackoffInitialDelayTests {
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(
        "A retry waits the initial delay, then multiplies it after each retry, capped at the maximum",
        .timeLimit(.minutes(1)))
    func retryWaitsGrowFromTheInitialDelayUpToTheCap() async throws {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        let clock = TrackedTestClock()
        let strategy = ExponentialBackoffStrategy<TrackedTestClock>(
            initialDelay: .seconds(1), multiplier: 2, maxCount: 9, maxDelay: .seconds(60))
        let expectedWaits: [Duration] = [1, 2, 4, 8, 16, 32, 60, 60].map { .seconds($0) }
        let justShort: Duration = .milliseconds(1)
        let stillSleeping = 1

        var iterator = stream.makeAsyncIterator()
        DeferredTask { continuation.yield() }
            .tryMap { _ in throw GeneralError.e1 }
            .retry(RetryByBackoffStrategy(strategy, clock: clock))
            .catch { err in
                DeferredTask {
                    continuation.finish()
                    throw err
                }
            }
            .run()

        // Each attempt yields once. Before each retry, time moves to just short of the wait (the
        // sleep is still registered), then to the wait itself, which runs the next attempt.
        await iterator.next()
        for wait in expectedWaits {
            try await clock.advance(by: wait - justShort, whenSleeping: 1)
            #expect(clock.sleepingCount == stillSleeping, "still waiting before \(wait)")
            await clock.advance(by: justShort)
            await iterator.next()
        }
        let actual: Void? = await iterator.next()

        #expect(actual == nil)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(
        "backoff waits the initial delay times the multiplier's powers, capped, ignoring the duration unit",
        .timeLimit(.minutes(1)))
    func backoffIgnoresTheDurationUnit() async throws {
        let clock = ImmediateClock<Duration>()
        let sut = ExponentialBackoffStrategy<ImmediateClock<Duration>>(
            initialDelay: .seconds(1), multiplier: 2, maxDelay: .seconds(60))
        let expected: [Duration] = [1, 2, 4, 8, 16, 32, 60, 60].map { .seconds($0) }

        var actual = [Duration]()
        for _ in expected {
            let start = clock.now
            let retried = try await sut.backoff(
                clock: clock, durationUnit: { (n: Int) in .milliseconds(n) })
            #expect(retried)
            actual.append(start.duration(to: clock.now))
        }

        #expect(actual == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(
        "A delay near the largest duration grows to the cap without trapping, and stays there",
        .timeLimit(.minutes(1)))
    func growthNearTheLargestDurationNeverTraps() async throws {
        /// Never suspends and never moves; records each wait it was asked for, so waits this long
        /// don't overflow its instant.
        final class RecordingClock: Clock, @unchecked Sendable {
            private let lock = NSLock()
            private var _waits = [Duration]()
            let now = ContinuousClock.now
            var waits: [Duration] { lock.withLock { _waits } }
            var minimumResolution: Duration { .zero }
            func sleep(until deadline: ContinuousClock.Instant, tolerance: Duration?) async throws {
                lock.withLock { _waits.append(now.duration(to: deadline)) }
            }
        }
        let clock = RecordingClock()
        // `Int64`, not `Int`: on a 32-bit `Int`, `Int.max / 2` doubled lands 1 s under the cap, a
        // different case from the one this test pins.
        let initialDelay: Duration = .seconds(Int64.max / 2)
        let cap: Duration = .seconds(Int64.max)
        let sut = ExponentialBackoffStrategy<RecordingClock>(
            initialDelay: initialDelay, multiplier: 2, maxDelay: cap)
        let expected = [initialDelay] + Array(repeating: cap, count: 199)

        for _ in expected {
            let retried = try await sut.backoff(
                clock: clock, durationUnit: { (n: Int) in .seconds(n) })
            #expect(retried)
        }
        let actual = clock.waits

        #expect(actual == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test("reset() starts the waits over at the initial delay", .timeLimit(.minutes(1)))
    func resetStartsOverAtTheInitialDelay() async throws {
        let clock = ImmediateClock<Duration>()
        let sut = ExponentialBackoffStrategy<ImmediateClock<Duration>>(
            initialDelay: .milliseconds(500), multiplier: 3, maxCount: 10)
        let expected: [Duration] = [
            .milliseconds(500), .milliseconds(1500), .milliseconds(4500), .milliseconds(500),
            .milliseconds(1500),
        ]

        var actual = [Duration]()
        for attempt in 0..<5 {
            if attempt == 3 { await sut.reset() }
            let start = clock.now
            let retried = try await sut.backoff(
                clock: clock, durationUnit: { (n: Int) in .seconds(n) })
            #expect(retried)
            actual.append(start.duration(to: clock.now))
        }

        #expect(actual == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(
        "Seeded jitter applies after the cap, so no wait passes the maximum delay",
        .timeLimit(.minutes(1)))
    func seededJitterStaysUnderTheCap() async throws {
        func delays(_ jitter: BackoffJitter) async throws -> [Duration] {
            let clock = ImmediateClock<Duration>()
            let sut = ExponentialBackoffStrategy<ImmediateClock<Duration>>(
                initialDelay: .seconds(1), multiplier: 2, maxDelay: .seconds(60), jitter: jitter)
            var delays = [Duration]()
            for _ in 0..<30 {
                let start = clock.now
                _ = try await sut.backoff(clock: clock, durationUnit: { (n: Int) in .seconds(n) })
                delays.append(start.duration(to: clock.now))
            }
            return delays
        }
        // The delay without jitter: 2^n seconds from n = 0, capped at 60.
        let exact = (0..<30).map { n -> Duration in n < 6 ? .seconds(1 << n) : .seconds(60) }
        let cap: Duration = .seconds(60)
        let seed: UInt64 = 0x5EED

        let full = try await delays(.full(using: SplitMix64(seed: seed)))
        let fullAgain = try await delays(.full(using: SplitMix64(seed: seed)))
        let equal = try await delays(.equal(using: SplitMix64(seed: seed)))
        let decorrelated = try await delays(.decorrelated(using: SplitMix64(seed: seed)))

        #expect(full == fullAgain)
        for (delay, ceiling) in zip(full, exact) {
            #expect(delay >= .zero && delay <= ceiling, "seed \(seed)")
        }
        for (delay, ceiling) in zip(equal, exact) {
            #expect(delay >= ceiling / 2 && delay <= ceiling, "seed \(seed)")
        }
        #expect(decorrelated.allSatisfy { $0 <= cap }, "seed \(seed)")
        #expect(Set(full).count > 1, "seed \(seed)")
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test("maxCount counts attempts: 3 allows two retries, then stops", .timeLimit(.minutes(1)))
    func maxCountEndsTheRetries() async throws {
        let clock = ImmediateClock<Duration>()
        let sut = ExponentialBackoffStrategy<ImmediateClock<Duration>>(
            initialDelay: .seconds(1), maxCount: 3)
        let expected = [true, true, false]

        var actual = [Bool]()
        for _ in expected {
            actual.append(
                try await sut.backoff(clock: clock, durationUnit: { (n: Int) in .seconds(n) }))
        }

        #expect(actual == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(
        "The .exponential(initialDelay:) factory retries through .backoff until maxCount",
        .timeLimit(.minutes(1)))
    func factoryRetriesThroughBackoff() async throws {
        actor Attempts {
            var count = 0
            func record() { count += 1 }
        }
        let attempts = Attempts()
        let expected = 3
        let expectedError = GeneralError.e1

        var thrown: (any Error)?
        do {
            try await DeferredTask { await attempts.record() }
                .tryMap { _ in throw GeneralError.e1 }
                .retry(.backoff(.exponential(initialDelay: .zero, maxCount: 3)))
                .execute()
        } catch {
            thrown = error
        }
        let actual = await attempts.count

        #expect(thrown as? GeneralError == expectedError)
        #expect(actual == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test("A multiplier of 1 waits the initial delay every time", .timeLimit(.minutes(1)))
    func multiplierOfOneWaitsConstantly() async throws {
        let clock = ImmediateClock<Duration>()
        let sut = ExponentialBackoffStrategy<ImmediateClock<Duration>>(
            initialDelay: .milliseconds(250), multiplier: 1)
        let expected: [Duration] = Array(repeating: .milliseconds(250), count: 5)

        var actual = [Duration]()
        for _ in expected {
            let start = clock.now
            _ = try await sut.backoff(clock: clock, durationUnit: { (n: Int) in .seconds(n) })
            actual.append(start.duration(to: clock.now))
        }

        #expect(actual == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(
        "An initial delay of zero waits nothing, however large the multiplier",
        .timeLimit(.minutes(1)))
    func zeroInitialDelayWaitsNothing() async throws {
        let clock = ImmediateClock<Duration>()
        let sut = ExponentialBackoffStrategy<ImmediateClock<Duration>>(
            initialDelay: .zero, multiplier: 10)
        let expected: [Duration] = Array(repeating: .zero, count: 5)

        var actual = [Duration]()
        for _ in expected {
            let start = clock.now
            let retried = try await sut.backoff(
                clock: clock, durationUnit: { (n: Int) in .seconds(n) })
            #expect(retried)
            actual.append(start.duration(to: clock.now))
        }

        #expect(actual == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(
        "An initial delay past the maximum waits the maximum from the first retry",
        .timeLimit(.minutes(1)))
    func initialDelayPastTheCapWaitsTheCap() async throws {
        let clock = ImmediateClock<Duration>()
        let sut = ExponentialBackoffStrategy<ImmediateClock<Duration>>(
            initialDelay: .seconds(100), maxDelay: .seconds(10))
        let expected: [Duration] = Array(repeating: .seconds(10), count: 3)

        var actual = [Duration]()
        for _ in expected {
            let start = clock.now
            _ = try await sut.backoff(clock: clock, durationUnit: { (n: Int) in .seconds(n) })
            actual.append(start.duration(to: clock.now))
        }

        #expect(actual == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(
        "The waits match min(initialDelay × multiplierⁱ, maxDelay) computed naively in seconds",
        .timeLimit(.minutes(1)))
    func waitsMatchANaiveReference() async throws {
        /// Never suspends and never moves; records each wait it was asked for.
        final class RecordingClock: Clock, @unchecked Sendable {
            private let lock = NSLock()
            private var _waits = [Duration]()
            let now = ContinuousClock.now
            var waits: [Duration] { lock.withLock { _waits } }
            var minimumResolution: Duration { .zero }
            func sleep(until deadline: ContinuousClock.Instant, tolerance: Duration?) async throws {
                lock.withLock { _waits.append(now.duration(to: deadline)) }
            }
        }
        let tolerance = 1e-9
        let waits = 16
        await propertyCheck(
            count: 200, input: Gen.int(in: 1...5000), Gen.double(in: 1...4),
            Gen.int(in: 1...600)
        ) { initialMilliseconds, multiplier, maxSeconds in
            let initial = Double(initialMilliseconds) / 1000
            let cap = Double(maxSeconds)
            let expected = (0..<waits).map { min(initial * pow(multiplier, Double($0)), cap) }
            let clock = RecordingClock()
            let sut = ExponentialBackoffStrategy<RecordingClock>(
                initialDelay: .milliseconds(initialMilliseconds), multiplier: multiplier,
                maxDelay: .seconds(maxSeconds))

            for _ in 0..<waits {
                _ = try await sut.backoff(clock: clock, durationUnit: { (n: Int) in .seconds(n) })
            }
            let actual = clock.waits.map { wait in
                Double(wait.components.seconds) + Double(wait.components.attoseconds) / 1e18
            }

            #expect(actual.count == expected.count)
            for (wait, reference) in zip(actual, expected) {
                #expect(abs(wait - reference) <= reference * tolerance, "\(actual) vs \(expected)")
            }
        }
    }
}
