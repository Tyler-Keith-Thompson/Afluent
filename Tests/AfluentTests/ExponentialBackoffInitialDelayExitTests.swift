//
//  ExponentialBackoffInitialDelayExitTests.swift
//  Afluent
//

// Exit tests start a child process, which only these platforms can.
#if os(macOS) || os(Linux) || os(Windows)
    import Afluent
    import Foundation
    import Testing

    struct ExponentialBackoffInitialDelayExitTests {
        @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
        @Test("A multiplier below 1 traps")
        func multiplierBelowOneTraps() async {
            await #expect(processExitsWith: .failure) {
                _ = ExponentialBackoffStrategy<ContinuousClock>(
                    initialDelay: .seconds(1), multiplier: 0.5)
            }
        }

        @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
        @Test("A multiplier that isn't finite traps")
        func infiniteMultiplierTraps() async {
            await #expect(processExitsWith: .failure) {
                _ = ExponentialBackoffStrategy<ContinuousClock>(
                    initialDelay: .seconds(1), multiplier: .infinity)
            }
        }

        @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
        @Test("A negative initial delay traps")
        func negativeInitialDelayTraps() async {
            await #expect(processExitsWith: .failure) {
                _ = ExponentialBackoffStrategy<ContinuousClock>(initialDelay: .seconds(-1))
            }
        }
    }
#endif
