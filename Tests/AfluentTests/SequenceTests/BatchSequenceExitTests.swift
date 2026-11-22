//
//  BatchSequenceExitTests.swift
//  Afluent
//

// Exit tests start a child process, which only these platforms can.
#if os(macOS) || os(Linux) || os(Windows)
    import Afluent
    import Foundation
    import Testing

    struct BatchSequenceExitTests {
        @Test("count(0) traps")
        func countOfZeroTraps() async {
            await #expect(processExitsWith: .failure) {
                _ = BatchStrategy.count(0)
            }
        }

        @Test("A negative count traps")
        func negativeCountTraps() async {
            await #expect(processExitsWith: .failure) {
                _ = BatchStrategy.count(-1)
            }
        }

        @available(macOS 13.0, *)
        @Test("time(interval:) with an interval of zero traps")
        func zeroIntervalTraps() async {
            await #expect(processExitsWith: .failure) {
                _ = BatchStrategy.time(interval: .zero, clock: ContinuousClock())
            }
        }

        @available(macOS 13.0, *)
        @Test("time(interval:) with a negative interval traps")
        func negativeIntervalTraps() async {
            await #expect(processExitsWith: .failure) {
                _ = BatchStrategy.time(interval: .seconds(-1), clock: ContinuousClock())
            }
        }
    }
#endif
