//
//  AnyAsyncSequenceTests.swift
//
//
//  Created by Tyler Thompson on 11/28/23.
//

import Afluent
import Foundation
import Testing

struct AnyAsyncSequenceTests {
    @Test func erasureOfAsyncSequence() async throws {
        let val = try await DeferredTask { true }.toAsyncSequence()
            .flatMap { branch -> AnyAsyncSequence<Int> in
                if branch {
                    return DeferredTask { 1 }.toAsyncSequence().eraseToAnyAsyncSequence()
                } else {
                    return DeferredTask { 0 }.toAsyncSequence().eraseToAnyAsyncSequence()
                }
            }.first()

        #expect(val == 1)
    }

    @Test func erasureOfAsyncSequence_OtherBranch() async throws {
        let val = try await DeferredTask { false }.toAsyncSequence()
            .flatMap { branch -> AnyAsyncSequence<Int> in
                if branch {
                    return DeferredTask { 1 }.toAsyncSequence().eraseToAnyAsyncSequence()
                } else {
                    return DeferredTask { 0 }.toAsyncSequence().eraseToAnyAsyncSequence()
                }
            }.first()

        #expect(val == 0)
    }

    @Test("An erased empty sequence of an Optional element finishes", .timeLimit(.minutes(1)))
    func erasedEmptySequenceOfOptionalFinishes() async throws {
        let sut = AsyncStream<Int?> { $0.finish() }.eraseToAnyAsyncSequence()
        let expected: [Int?] = []

        var actual: [Int?] = []
        for try await element in sut {
            actual.append(element)
        }

        #expect(actual == expected)
    }

    @Test(
        "An erased sequence of an Optional element yields its nils and then finishes",
        .timeLimit(.minutes(1)))
    func erasedSequenceOfOptionalYieldsNilsAndFinishes() async throws {
        let sut = AsyncStream<Int?> { continuation in
            continuation.yield(1)
            continuation.yield(nil)
            continuation.yield(2)
            continuation.finish()
        }.eraseToAnyAsyncSequence()
        let expected: [Int?] = [1, nil, 2]

        var actual: [Int?] = []
        for try await element in sut {
            actual.append(element)
        }

        #expect(actual == expected)
    }

    @Test(
        "An erased sequence of a non-Optional element yields its elements and then finishes",
        .timeLimit(.minutes(1)))
    func erasedSequenceOfNonOptionalYieldsElementsAndFinishes() async throws {
        let sut = AsyncStream<Int> { continuation in
            continuation.yield(1)
            continuation.yield(2)
            continuation.finish()
        }.eraseToAnyAsyncSequence()
        let expected: [Int] = [1, 2]

        var actual: [Int] = []
        for try await element in sut {
            actual.append(element)
        }

        #expect(actual == expected)
    }
}
