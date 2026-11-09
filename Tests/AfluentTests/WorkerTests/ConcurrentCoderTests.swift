//
//  ConcurrentCoderTests.swift
//  Afluent
//

import Afluent
import Foundation
import Testing

struct ConcurrentCoderTests {
    @Test(
        "A non-Sendable encoder and decoder shared by 8 concurrent tasks round-trip every value, one call at a time",
        .timeLimit(.minutes(1)))
    func nonSendableCodersRoundTripFromConcurrentTasks() async throws {
        // Not Sendable: it counts calls that overlap, which a missing lock would show.
        final class OverlapCountingEncoder: TopLevelEncoder {
            private let base = JSONEncoder()
            private var inUse = false
            private(set) var overlaps = 0
            private(set) var calls = 0
            func encode<T: Encodable>(_ value: T) throws -> Data {
                if inUse { overlaps += 1 }
                inUse = true
                defer { inUse = false }
                calls += 1
                // Long enough for an unguarded call from another task to overlap.
                usleep(1_000)
                return try base.encode(value)
            }
        }
        final class OverlapCountingDecoder: TopLevelDecoder {
            private let base = JSONDecoder()
            private var inUse = false
            private(set) var overlaps = 0
            private(set) var calls = 0
            func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
                if inUse { overlaps += 1 }
                inUse = true
                defer { inUse = false }
                calls += 1
                usleep(1_000)
                return try base.decode(type, from: data)
            }
        }

        let encoder = OverlapCountingEncoder()
        let decoder = OverlapCountingDecoder()
        let expected = 42
        let roundTrip = DeferredTask { expected }
            .encode(encoder: encoder)
            .decode(type: Int.self, decoder: decoder)
        let tasks = 8
        let results = try await withThrowingTaskGroup(of: Int.self, returning: [Int].self) { group in
            for _ in 0..<tasks {
                group.addTask { try await roundTrip.execute() }
            }
            var results = [Int]()
            for try await result in group { results.append(result) }
            return results
        }

        let expectedResults = Array(repeating: expected, count: tasks)
        #expect(results == expectedResults)
        #expect(encoder.calls == tasks)
        #expect(decoder.calls == tasks)
        #expect(encoder.overlaps == 0)
        #expect(decoder.overlaps == 0)
    }

    @Test(
        "A non-Sendable encoder and decoder shared by 8 concurrent iterations of a sequence round-trip every value, one call at a time",
        .timeLimit(.minutes(1)))
    func nonSendableCodersRoundTripFromConcurrentSequenceIterations() async throws {
        final class OverlapCountingEncoder: TopLevelEncoder {
            private let base = JSONEncoder()
            private var inUse = false
            private(set) var overlaps = 0
            private(set) var calls = 0
            func encode<T: Encodable>(_ value: T) throws -> Data {
                if inUse { overlaps += 1 }
                inUse = true
                defer { inUse = false }
                calls += 1
                usleep(1_000)
                return try base.encode(value)
            }
        }
        final class OverlapCountingDecoder: TopLevelDecoder {
            private let base = JSONDecoder()
            private var inUse = false
            private(set) var overlaps = 0
            private(set) var calls = 0
            func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
                if inUse { overlaps += 1 }
                inUse = true
                defer { inUse = false }
                calls += 1
                usleep(1_000)
                return try base.decode(type, from: data)
            }
        }

        let encoder = OverlapCountingEncoder()
        let decoder = OverlapCountingDecoder()
        let expected = 42
        let roundTrip = Just(expected)
            .encode(encoder: encoder)
            .decode(type: Int.self, decoder: decoder)
        let tasks = 8
        let results = try await withThrowingTaskGroup(of: [Int].self, returning: [Int].self) { group in
            for _ in 0..<tasks {
                group.addTask {
                    var received = [Int]()
                    for try await value in roundTrip { received.append(value) }
                    return received
                }
            }
            var results = [Int]()
            for try await received in group { results.append(contentsOf: received) }
            return results
        }

        let expectedResults = Array(repeating: expected, count: tasks)
        #expect(results == expectedResults)
        #expect(encoder.calls == tasks)
        #expect(decoder.calls == tasks)
        #expect(encoder.overlaps == 0)
        #expect(decoder.overlaps == 0)
    }
}
