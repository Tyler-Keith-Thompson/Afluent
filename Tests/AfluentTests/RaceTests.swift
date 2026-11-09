//
//  RaceTests.swift
//  Afluent
//

import Afluent
import Testing

struct RaceTests {
    @Test("Race returns the first task to finish and cancels the others", .timeLimit(.minutes(1)))
    func raceReturnsTheWinnerAndCancelsTheLoser() async throws {
        // The loser waits on a stream that never yields, so only cancellation ends it; it reports what it saw.
        let (neverYields, neverYieldsContinuation) = AsyncStream<Void>.makeStream()
        let (loserEnded, loserEndedContinuation) = AsyncStream<Bool>.makeStream()
        let expected = 2
        let result = try await Race {
            for await _ in neverYields {}
            loserEndedContinuation.yield(Task.isCancelled)
            return 1
        } against: {
            expected
        }
        #expect(result == expected)
        var loserWasCancelled: Bool?
        for await value in loserEnded {
            loserWasCancelled = value
            break
        }
        #expect(loserWasCancelled == true)
        neverYieldsContinuation.finish()
    }

    @Test("A task that throws wins the race: Race throws its error and cancels the others", .timeLimit(.minutes(1)))
    func raceThrowsTheFirstErrorAndCancelsTheOthers() async throws {
        struct Failed: Error {}
        let (neverYields, neverYieldsContinuation) = AsyncStream<Void>.makeStream()
        let (loserEnded, loserEndedContinuation) = AsyncStream<Bool>.makeStream()
        let result = await Task { () async throws -> Int in
            try await Race { () async -> Int in
                for await _ in neverYields {}
                loserEndedContinuation.yield(Task.isCancelled)
                return 1
            } against: { () throws -> Int in
                throw Failed()
            }
        }.result
        func getResult() throws -> Int { try result.get() }
        #expect(throws: Failed.self, performing: getResult)
        var loserWasCancelled: Bool?
        for await value in loserEnded {
            loserWasCancelled = value
            break
        }
        #expect(loserWasCancelled == true)
        neverYieldsContinuation.finish()
    }

    @Test("Race takes more than two tasks")
    func raceTakesMoreThanTwoTasks() async throws {
        let (neverYields, neverYieldsContinuation) = AsyncStream<Void>.makeStream()
        @Sendable func waitForCancellation() async -> Int {
            for await _ in neverYields {}
            return 0
        }
        let expected = 3
        let result = try await Race(waitForCancellation, against: waitForCancellation, { expected })
        #expect(result == expected)
        neverYieldsContinuation.finish()
    }
}
