//
//  CriticalStateTests.swift
//  Afluent
//

import Testing

@testable import Afluent

struct CriticalStateTests {
    @Test("A CriticalState is uniquely referenced until it is copied")
    func uniquenessFollowsCopies() {
        var state = CriticalState(0)
        let freshIsUnique = state.isKnownUniquelyReferenced()
        #expect(freshIsUnique)

        let copy = state
        let copiedIsUnique = state.isKnownUniquelyReferenced()
        #expect(copiedIsUnique == false)
        _ = copy
    }

    @Test("Concurrent critical regions on a CriticalState don't lose updates")
    func concurrentRegionsDoNotLoseUpdates() async {
        let state = CriticalState(0)
        let tasks = 8
        let incrementsPerTask = 1_000
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<tasks {
                group.addTask {
                    for _ in 0..<incrementsPerTask {
                        state.withCriticalRegion { $0 += 1 }
                    }
                }
            }
        }
        let expected = tasks * incrementsPerTask
        let total = state.withCriticalRegion { $0 }
        #expect(total == expected)
    }
}

#if canImport(Darwin)
    /// The fallback tier runs only on Apple OSes without `Mutex`, so these tests construct it directly.
    struct UnfairLockStorageTests {
        struct Failure: Error {}

        @Test("Concurrent regions on the unfair-lock storage don't lose updates")
        func concurrentRegionsDoNotLoseUpdates() async {
            let storage = UnfairLockStorage.make(0)
            let tasks = 8
            let incrementsPerTask = 1_000
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<tasks {
                    group.addTask {
                        for _ in 0..<incrementsPerTask {
                            storage.withLock { $0 += 1 }
                        }
                    }
                }
            }
            let expected = tasks * incrementsPerTask
            let total = storage.withLock { $0 }
            #expect(total == expected)
        }

        @Test("The unfair-lock storage unlocks when its region throws", .timeLimit(.minutes(1)))
        func unlocksAfterAThrow() throws {
            let storage = UnfairLockStorage.make(0)
            func throwInsideTheRegion() throws {
                try storage.withLock { value in
                    value = 1
                    throw Failure()
                }
            }
            #expect(throws: Failure.self) { try throwInsideTheRegion() }

            let expected = 1
            let afterThrow = storage.withLock { $0 }
            #expect(afterThrow == expected)
        }

        @Test("The unfair-lock storage destroys its state when it is released")
        func releasesItsState() {
            final class Tracked: Sendable {}
            weak var tracked: Tracked?
            do {
                let value = Tracked()
                tracked = value
                let storage = UnfairLockStorage.make(value)
                let stored = storage.withLock { $0 === value }
                #expect(stored)
            }
            #expect(tracked == nil)
        }
    }
#endif
