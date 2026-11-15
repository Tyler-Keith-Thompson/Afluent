//
//  ExponentialBackoffResetAndJitterTests.swift
//  Afluent
//

import Afluent
import Clocks
import Foundation
import Testing

struct ExponentialBackoffResetAndJitterTests {
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(.timeLimit(.minutes(1))) func resetStartsTheDelaysOver() async throws {
        let clock = ImmediateClock<Duration>()
        let strategy = ExponentialBackoffStrategy<ImmediateClock<Duration>>(base: 2, maxCount: 10)
        let expected: [Duration] = [.seconds(2), .seconds(4), .seconds(8), .seconds(2), .seconds(4)]

        var delays = [Duration]()
        for attempt in 0 ..< 5 {
            if attempt == 3 { await strategy.reset() }
            let start = clock.now
            let retried = try await strategy.backoff(clock: clock, durationUnit: { (n: Int) in .seconds(n) })
            #expect(retried)
            delays.append(start.duration(to: clock.now))
        }

        #expect(delays == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(.timeLimit(.minutes(1))) func resetLetsAStrategyThatRanOutRetryAgain() async throws {
        let clock = ImmediateClock<Duration>()
        let strategy = ExponentialBackoffStrategy<ImmediateClock<Duration>>(base: 2, maxCount: 2)

        let first = try await strategy.backoff(clock: clock, durationUnit: { (n: Int) in .seconds(n) })
        let exhausted = try await strategy.backoff(clock: clock, durationUnit: { (n: Int) in .seconds(n) })
        await strategy.reset()
        let afterReset = try await strategy.backoff(clock: clock, durationUnit: { (n: Int) in .seconds(n) })

        #expect(first)
        #expect(!exhausted)
        #expect(afterReset)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(.timeLimit(.minutes(1))) func withoutAMaxCountTheStrategyNeverStopsAndTheDelayStaysCapped()
        async throws
    {
        let clock = ImmediateClock<Duration>()
        let strategy = ExponentialBackoffStrategy<ImmediateClock<Duration>>(
            base: 2, maxDelay: .seconds(60))
        let cap: Duration = .seconds(60)

        // Far past 2^63, where the exponent no longer fits in an Int.
        var lastDelay: Duration = .zero
        for _ in 0 ..< 200 {
            let start = clock.now
            let retried = try await strategy.backoff(clock: clock, durationUnit: { (n: Int) in .seconds(n) })
            #expect(retried)
            lastDelay = start.duration(to: clock.now)
        }

        #expect(lastDelay == cap)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(.timeLimit(.minutes(1))) func noJitterWaitsExactlyTheDelay() async throws {
        let clock = ImmediateClock<Duration>()
        let strategy = ExponentialBackoffStrategy<ImmediateClock<Duration>>(
            base: 3, maxCount: 10, jitter: .none)
        let expected: [Duration] = [.seconds(3), .seconds(9), .seconds(27)]

        var delays = [Duration]()
        for _ in 0 ..< 3 {
            let start = clock.now
            _ = try await strategy.backoff(clock: clock, durationUnit: { (n: Int) in .seconds(n) })
            delays.append(start.duration(to: clock.now))
        }

        #expect(delays == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(.timeLimit(.minutes(1))) func fullJitterAtTheLowestDrawWaitsNothing() async throws {
        /// Always draws zero.
        struct Zeros: RandomNumberGenerator, Sendable {
            mutating func next() -> UInt64 { 0 }
        }
        let clock = ImmediateClock<Duration>()
        let strategy = ExponentialBackoffStrategy<ImmediateClock<Duration>>(
            base: 2, maxCount: 10, jitter: .full(using: Zeros()))
        let expected: Duration = .zero

        let start = clock.now
        _ = try await strategy.backoff(clock: clock, durationUnit: { (n: Int) in .seconds(n) })

        #expect(start.duration(to: clock.now) == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(.timeLimit(.minutes(1))) func equalJitterAtTheLowestDrawWaitsHalfTheCappedDelay() async throws {
        /// Always draws zero.
        struct Zeros: RandomNumberGenerator, Sendable {
            mutating func next() -> UInt64 { 0 }
        }
        let clock = ImmediateClock<Duration>()
        let strategy = ExponentialBackoffStrategy<ImmediateClock<Duration>>(
            base: 2, maxCount: 10, maxDelay: .seconds(5), jitter: .equal(using: Zeros()))
        // 2, 4, then 8 capped at 5: half of each.
        let expected: [Duration] = [.seconds(1), .seconds(2), .milliseconds(2500)]

        var delays = [Duration]()
        for _ in 0 ..< 3 {
            let start = clock.now
            _ = try await strategy.backoff(clock: clock, durationUnit: { (n: Int) in .seconds(n) })
            delays.append(start.duration(to: clock.now))
        }

        #expect(delays == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(.timeLimit(.minutes(1))) func seededJitterStaysInItsRangeAndReproducesFromTheSeed()
        async throws
    {
        /// SplitMix64: a small seeded generator, so a failure reproduces from its seed.
        struct SplitMix64: RandomNumberGenerator, Sendable {
            var state: UInt64
            mutating func next() -> UInt64 {
                state &+= 0x9E37_79B9_7F4A_7C15
                var z = state
                z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
                z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
                return z ^ (z >> 31)
            }
        }
        func delays(_ jitter: BackoffJitter) async throws -> [Duration] {
            let clock = ImmediateClock<Duration>()
            let strategy = ExponentialBackoffStrategy<ImmediateClock<Duration>>(
                base: 2, maxDelay: .seconds(60), jitter: jitter)
            var delays = [Duration]()
            for _ in 0 ..< 100 {
                let start = clock.now
                _ = try await strategy.backoff(clock: clock, durationUnit: { (n: Int) in .seconds(n) })
                delays.append(start.duration(to: clock.now))
            }
            return delays
        }
        // The delay without jitter: 2^n seconds, capped at 60.
        let exact = (1 ... 100).map { n -> Duration in n < 6 ? .seconds(1 << n) : .seconds(60) }
        let seed: UInt64 = 0x5EED

        let full = try await delays(.full(using: SplitMix64(state: seed)))
        let fullAgain = try await delays(.full(using: SplitMix64(state: seed)))
        let equal = try await delays(.equal(using: SplitMix64(state: seed)))

        #expect(full == fullAgain)
        for (delay, ceiling) in zip(full, exact) {
            #expect(delay >= .zero && delay <= ceiling, "seed \(seed)")
        }
        for (delay, ceiling) in zip(equal, exact) {
            #expect(delay >= ceiling / 2 && delay <= ceiling, "seed \(seed)")
        }
        #expect(Set(full).count > 1, "seed \(seed)")
    }
}
