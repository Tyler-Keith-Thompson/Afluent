//
//  FailSequenceTests.swift
//  Afluent
//

import Afluent
import Foundation
import Testing

@Suite(.timeLimit(.minutes(1)))
struct FailSequenceTests {
    @Test func firstThrowsTheErrorWithoutAnElement() async throws {
        struct Expected: Error, Equatable {}
        let sut = Fail<Int>(error: Expected())

        await #expect(throws: Expected()) { try await sut.first() }
    }

    @Test func iteratingThrowsTheErrorBeforeAnyElement() async throws {
        struct Expected: Error, Equatable {}
        let sut = Fail(outputType: Int.self, error: Expected())
        var actual = [Int]()

        func iterate() async throws {
            for try await element in sut { actual.append(element) }
        }
        await #expect(throws: Expected()) { try await iterate() }

        #expect(actual.isEmpty)
    }

    @Test func everyCallAfterTheErrorReturnsNil() async throws {
        struct Expected: Error, Equatable {}
        var iterator = Fail<Int>(error: Expected()).makeAsyncIterator()

        await #expect(throws: Expected()) { try await iterator.next() }
        let second = try await iterator.next()
        let third = try await iterator.next()

        #expect(second == nil)
        #expect(third == nil)
    }

    @Test func eachIteratorThrowsTheErrorFromTheStart() async throws {
        struct Expected: Error, Equatable {}
        let sut = Fail<Int>(error: Expected())
        var first = sut.makeAsyncIterator()
        var second = sut.makeAsyncIterator()

        await #expect(throws: Expected()) { try await first.next() }
        await #expect(throws: Expected()) { try await second.next() }
    }

    @Test func aCancelledTaskStillGetsTheErrorRatherThanCancellation() async throws {
        struct Expected: Error, Equatable {}
        let sut = Fail<Int>(error: Expected())
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await sut.first()
        }

        await #expect(throws: Expected()) { try await task.value }
    }
}
