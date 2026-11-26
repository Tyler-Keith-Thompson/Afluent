//
//  ExponentialBackoffCountTests.swift
//  Afluent
//

import Clocks
import Foundation
import Testing

@testable import Afluent

struct ExponentialBackoffCountTests {
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(.timeLimit(.minutes(1)))
    func anUnlimitedStrategyKeepsRetryingPastIntMaxAtMaxDelay() async throws {
        let clock = ImmediateClock<Duration>()
        let strategy = ExponentialBackoffStrategy<ImmediateClock<Duration>>(
            base: 2, maxDelay: .seconds(5))
        let startingCount = UInt(Int.max)
        await strategy.setCount(startingCount)
        let expected: [Duration] = [.seconds(5), .seconds(5), .seconds(5)]

        var delays = [Duration]()
        for _ in 0 ..< 3 {
            let start = clock.now
            let retried = try await strategy.backoff(clock: clock, durationUnit: { (n: Int) in .seconds(n) })
            #expect(retried)
            delays.append(start.duration(to: clock.now))
        }

        #expect(delays == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(.timeLimit(.minutes(1)))
    func anUnlimitedStrategyKeepsRetryingOnceItsCountReachesUIntMax() async throws {
        let clock = ImmediateClock<Duration>()
        let strategy = ExponentialBackoffStrategy<ImmediateClock<Duration>>(
            base: 2, maxDelay: .seconds(5))
        let startingCount = UInt.max - 1
        await strategy.setCount(startingCount)
        let expected: [Duration] = [.seconds(5), .seconds(5), .seconds(5)]

        var delays = [Duration]()
        for _ in 0 ..< 3 {
            let start = clock.now
            let retried = try await strategy.backoff(clock: clock, durationUnit: { (n: Int) in .seconds(n) })
            #expect(retried)
            delays.append(start.duration(to: clock.now))
        }

        #expect(delays == expected)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test(.timeLimit(.minutes(1)))
    func aStrategyWithAMaxCountPastIntMaxStopsOnceItIsReached() async throws {
        let clock = ImmediateClock<Duration>()
        let maxCount = UInt(Int.max) + 1
        let strategy = ExponentialBackoffStrategy<ImmediateClock<Duration>>(
            base: 2, maxCount: maxCount, maxDelay: .seconds(5))
        let startingCount = UInt(Int.max)
        await strategy.setCount(startingCount)

        let last = try await strategy.backoff(clock: clock, durationUnit: { (n: Int) in .seconds(n) })
        let exhausted = try await strategy.backoff(clock: clock, durationUnit: { (n: Int) in .seconds(n) })

        #expect(last)
        #expect(!exhausted)
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension ExponentialBackoffStrategy {
    fileprivate func setCount(_ newCount: UInt) {
        count = newCount
    }
}
