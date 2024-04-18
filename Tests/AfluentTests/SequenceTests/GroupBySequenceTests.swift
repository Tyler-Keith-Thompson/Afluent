//
//  GroupBySequenceTests.swift
//
//
//  Created by Trip Phillips on 2/29/24.
//

import Clocks
import ConcurrencyExtras
import Foundation
import Testing
@testable import Afluent

struct GroupBySequenceTests {
    enum TestError: Error {
        case upstreamError
    }

    @Test func groupByChecksCancellation() async throws {
        let stream = AsyncStream<Int> { continuation in
            continuation.finish()
        }.groupBy { $0 }

        let task = Task {
            for try await _ in stream { }
        }

        task.cancel()

        let result = await task.result

        #expect(throws: CancellationError.self) { try result.get() }
    }

    @Test func groupByWithEmptySequenceReturnsEmptyKeys() async throws {
        let stream = AsyncStream<String> { continuation in
            continuation.finish()
        }.groupBy { $0.uppercased() }
            .map(\.key)
            .collect()

        let keys = try await stream.first()
        #expect(keys?.isEmpty != false)
    }

    @Test func groupByWithPopulatedSequenceReturnsKeysWithoutTransformation() async throws {
        let stream = AsyncStream<String> { continuation in
            continuation.yield("a")
            continuation.yield("b")
            continuation.yield("c")
            continuation.yield("d")
            continuation.yield("e")
            continuation.yield("f")
            continuation.yield("g")
            continuation.finish()
        }.groupBy { $0 }
            .map(\.key)
            .collect()

        let keys = try await stream.first()
        #expect(keys == ["a", "b", "c", "d", "e", "f", "g"])
    }

    @Test func groupByWithPopulatedSequenceReturnsKeysWithTransformation() async throws {
        let stream = AsyncStream<String> { continuation in
            continuation.yield("a")
            continuation.yield("b")
            continuation.yield("c")
            continuation.yield("d")
            continuation.yield("e")
            continuation.yield("f")
            continuation.yield("g")
            continuation.finish()
        }.groupBy { $0.uppercased() }
            .map(\.key)
            .collect()

        let keys = try await stream.first()
        #expect(keys == ["A", "B", "C", "D", "E", "F", "G"])
    }

    @Test func groupByWithPopulatedSequenceGroupsByKeys() async throws {
        let stream = AsyncStream<String> { continuation in
            continuation.yield("a")
            continuation.yield("b")
            continuation.yield("c")
            continuation.yield("c")
            continuation.yield("d")
            continuation.yield("e")
            continuation.yield("f")
            continuation.yield("g")
            continuation.finish()
        }.groupBy { $0 }
            .map(\.key)
            .collect()

        let keys = try await stream.first()
        #expect(keys == ["a", "b", "c", "d", "e", "f", "g"])
    }

    @Test func groupByWithPopulatedSequenceGroupsByKeysWithSequences() async throws {
        let stream = AsyncStream<String> { continuation in
            continuation.yield("a")
            continuation.yield("b")
            continuation.yield("c")
            continuation.yield("c")
            continuation.yield("d")
            continuation.yield("e")
            continuation.yield("f")
            continuation.yield("g")
            continuation.finish()
        }.groupBy { $0 }

        var results = [String: AsyncThrowingStream<String, Error>]()

        for try await sequence in stream {
            results[sequence.key] = sequence.stream
        }

        #expect(results.keys.count == 7)

        let a = try await results["a"]?.collect().first()
        #expect(a == ["a"])

        let b = try await results["b"]?.collect().first()
        #expect(b == ["b"])

        let c = try await results["c"]?.collect().first()
        #expect(c == ["c", "c"])

        let d = try await results["d"]?.collect().first()
        #expect(d == ["d"])

        let e = try await results["e"]?.collect().first()
        #expect(e == ["e"])

        let f = try await results["f"]?.collect().first()
        #expect(f == ["f"])

        let g = try await results["g"]?.collect().first()
        #expect(g == ["g"])
    }

    @Test func groupByWithPopulatedSequenceGroupsByKeysWithSequences_throwingError() async throws {
        let stream = AsyncThrowingStream<String, Error> { continuation in
            continuation.yield("a")
            continuation.yield("b")
            continuation.yield("c")
            continuation.yield("c")
            continuation.yield("d")
            continuation.yield("e")
            continuation.yield(with: .failure(TestError.upstreamError))
            continuation.yield("f")
            continuation.yield("g")
            continuation.finish()
        }.groupBy { $0 }

        var results = [String: AsyncThrowingStream<String, Error>]()
        do {
            for try await sequence in stream {
                results[sequence.key] = sequence.stream
            }

            #expect(results.keys.count == 5)

            let a = try await results["a"]?.collect().first()
            #expect(a == ["a"])

            let b = try await results["b"]?.collect().first()
            #expect(b == ["b"])

            let c = try await results["c"]?.collect().first()
            #expect(c == ["c", "c"])

            let d = try await results["d"]?.collect().first()
            #expect(d == ["d"])

            let e = try await results["e"]?.collect().first()
            #expect(e == ["e"])

            let f = try await results["f"]?.collect().first()
            #expect(f != ["f"])

            let g = try await results["g"]?.collect().first()
            #expect(g != ["g"])
        } catch {
            guard case TestError.upstreamError = error else {
                Issue.record("No error thrown")
                return
            }
        }
    }

    @Test func groupByWithPopulatedSequenceGroupsByKeysWithSequences_completingWithError() async throws {
        let stream = AsyncThrowingStream<String, Error> { continuation in
            continuation.yield("a")
            continuation.yield("b")
            continuation.yield("c")
            continuation.yield("c")
            continuation.yield("d")
            continuation.yield("e")
            continuation.finish(throwing: TestError.upstreamError)
            continuation.yield("f")
            continuation.yield("g")
        }.groupBy { $0 }

        var results = [String: AsyncThrowingStream<String, Error>]()
        do {
            for try await sequence in stream {
                results[sequence.key] = sequence.stream
            }

            #expect(results.keys.count == 5)

            let a = try await results["a"]?.collect().first()
            #expect(a == ["a"])

            let b = try await results["b"]?.collect().first()
            #expect(b == ["b"])

            let c = try await results["c"]?.collect().first()
            #expect(c == ["c", "c"])

            let d = try await results["d"]?.collect().first()
            #expect(d == ["d"])

            let e = try await results["e"]?.collect().first()
            #expect(e == ["e"])

            let f = try await results["f"]?.collect().first()
            #expect(f != ["f"])

            let g = try await results["g"]?.collect().first()
            #expect(g != ["g"])
        } catch {
            guard case TestError.upstreamError = error else {
                Issue.record("No error thrown")
                return
            }
        }
    }
}
