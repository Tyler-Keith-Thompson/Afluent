//
//  ExponentialBackoffArgumentTests.swift
//  Afluent
//

import Afluent
import Atomics
import Foundation
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ExponentialBackoffArgumentTests {
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test("A negative initial delay ends the retry with NegativeInitialDelay after the first attempt")
    func negativeInitialDelayThrows() async throws {
        struct Failure: Error {}
        let attempts = ManagedAtomic(0)
        let expectedAttempts: Int = 1
        let strategy = ExponentialBackoffStrategy<ContinuousClock>(initialDelay: .seconds(-1))
        let sut = DeferredTask {
            attempts.wrappingIncrement(ordering: .relaxed)
            throw Failure()
        }
        .retry(RetryByBackoffStrategy(strategy, clock: ContinuousClock()))

        await #expect(throws: ExponentialBackoffStrategy<ContinuousClock>.NegativeInitialDelay()) {
            try await sut.execute()
        }

        #expect(attempts.load(ordering: .relaxed) == expectedAttempts)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test("A multiplier below 1 makes backoff throw InvalidMultiplier")
    func multiplierBelowOneThrows() async throws {
        let sut = ExponentialBackoffStrategy<ContinuousClock>(
            initialDelay: .seconds(1), multiplier: 0.5)

        await #expect(throws: ExponentialBackoffStrategy<ContinuousClock>.InvalidMultiplier()) {
            try await sut.backoff(clock: ContinuousClock(), durationUnit: { (power: Int) in .seconds(power) })
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test("An infinite multiplier makes backoff throw InvalidMultiplier")
    func infiniteMultiplierThrows() async throws {
        let sut = ExponentialBackoffStrategy<ContinuousClock>(
            initialDelay: .seconds(1), multiplier: .infinity)

        await #expect(throws: ExponentialBackoffStrategy<ContinuousClock>.InvalidMultiplier()) {
            try await sut.backoff(clock: ContinuousClock(), durationUnit: { (power: Int) in .seconds(power) })
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test("A NaN multiplier makes backoff throw InvalidMultiplier")
    func nanMultiplierThrows() async throws {
        let sut = ExponentialBackoffStrategy<ContinuousClock>(
            initialDelay: .seconds(1), multiplier: .nan)

        await #expect(throws: ExponentialBackoffStrategy<ContinuousClock>.InvalidMultiplier()) {
            try await sut.backoff(clock: ContinuousClock(), durationUnit: { (power: Int) in .seconds(power) })
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test("An out-of-range argument throws even once maxCount attempts have been made")
    func outOfRangeArgumentThrowsBeforeMaxCountIsChecked() async throws {
        let sut = ExponentialBackoffStrategy<ContinuousClock>(
            initialDelay: .seconds(-1), maxCount: 1)

        await #expect(throws: ExponentialBackoffStrategy<ContinuousClock>.NegativeInitialDelay()) {
            try await sut.backoff(clock: ContinuousClock(), durationUnit: { (power: Int) in .seconds(power) })
        }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test("An initial delay of zero and a multiplier of 1, the edges of their ranges, retry")
    func zeroInitialDelayAndMultiplierOfOneRetry() async throws {
        let expected: Bool = true
        let sut = ExponentialBackoffStrategy<ContinuousClock>(
            initialDelay: .zero, multiplier: 1, maxCount: 2)

        let actual = try await sut.backoff(clock: ContinuousClock(), durationUnit: { (power: Int) in .seconds(power) })

        #expect(actual == expected)
    }
}
