//
//  RetryConsecutiveFailuresTests.swift
//  Afluent
//

import Afluent
import Atomics
import Foundation
import Testing

struct RetryConsecutiveFailuresTests {
    // Each failure used to add a call frame until an element arrived; a loop keeps it flat.
    @Test(.timeLimit(.minutes(1))) func retryWithACountYieldsAfterTenThousandConsecutiveFailures() async throws {
        struct Refused: Error, Equatable {}
        /// Throws on each of the first `failures` attempts, then yields 42 and finishes.
        struct FailsThenYields: AsyncSequence, Sendable {
            let failures: Int
            let attempts: ManagedAtomic<Int>
            struct AsyncIterator: AsyncIteratorProtocol {
                let failures: Int
                let attempts: ManagedAtomic<Int>
                var finished = false
                mutating func next() async throws -> Int? {
                    guard !finished else { return nil }
                    if attempts.loadThenWrappingIncrement(ordering: .relaxed) < failures {
                        throw Refused()
                    }
                    finished = true
                    return 42
                }
            }
            func makeAsyncIterator() -> AsyncIterator {
                AsyncIterator(failures: failures, attempts: attempts)
            }
        }
        let failures = 10_000
        let attempts = ManagedAtomic(0)
        let upstream = FailsThenYields(failures: failures, attempts: attempts)
        let expected: [Int] = [42]
        let expectedAttempts = failures + 1

        var received = [Int]()
        for try await element in upstream.retry(UInt(failures)) {
            received.append(element)
        }

        #expect(received == expected)
        #expect(attempts.load(ordering: .relaxed) == expectedAttempts)
    }

    // Each failure used to add a call frame until an element arrived; a loop keeps it flat.
    @Test(.timeLimit(.minutes(1))) func retryWithAStrategyYieldsAfterTenThousandConsecutiveFailures() async throws {
        struct Refused: Error, Equatable {}
        /// Throws on each of the first `failures` attempts, then yields 42 and finishes.
        struct FailsThenYields: AsyncSequence, Sendable {
            let failures: Int
            let attempts: ManagedAtomic<Int>
            struct AsyncIterator: AsyncIteratorProtocol {
                let failures: Int
                let attempts: ManagedAtomic<Int>
                var finished = false
                mutating func next() async throws -> Int? {
                    guard !finished else { return nil }
                    if attempts.loadThenWrappingIncrement(ordering: .relaxed) < failures {
                        throw Refused()
                    }
                    finished = true
                    return 42
                }
            }
            func makeAsyncIterator() -> AsyncIterator {
                AsyncIterator(failures: failures, attempts: attempts)
            }
        }
        let failures = 10_000
        let attempts = ManagedAtomic(0)
        let upstream = FailsThenYields(failures: failures, attempts: attempts)
        let expected: [Int] = [42]
        let expectedAttempts = failures + 1

        var received = [Int]()
        for try await element in upstream.retry(RetryByCountStrategy(retryCount: UInt(failures))) {
            received.append(element)
        }

        #expect(received == expected)
        #expect(attempts.load(ordering: .relaxed) == expectedAttempts)
    }

    // Each failure used to add a call frame until an element arrived; a loop keeps it flat.
    @Test(.timeLimit(.minutes(1))) func retryOnAnErrorYieldsAfterTenThousandConsecutiveFailures() async throws {
        struct Refused: Error, Equatable {}
        /// Throws on each of the first `failures` attempts, then yields 42 and finishes.
        struct FailsThenYields: AsyncSequence, Sendable {
            let failures: Int
            let attempts: ManagedAtomic<Int>
            struct AsyncIterator: AsyncIteratorProtocol {
                let failures: Int
                let attempts: ManagedAtomic<Int>
                var finished = false
                mutating func next() async throws -> Int? {
                    guard !finished else { return nil }
                    if attempts.loadThenWrappingIncrement(ordering: .relaxed) < failures {
                        throw Refused()
                    }
                    finished = true
                    return 42
                }
            }
            func makeAsyncIterator() -> AsyncIterator {
                AsyncIterator(failures: failures, attempts: attempts)
            }
        }
        let failures = 10_000
        let attempts = ManagedAtomic(0)
        let upstream = FailsThenYields(failures: failures, attempts: attempts)
        let expected: [Int] = [42]
        let expectedAttempts = failures + 1

        var received = [Int]()
        for try await element in upstream.retry(UInt(failures), on: Refused()) {
            received.append(element)
        }

        #expect(received == expected)
        #expect(attempts.load(ordering: .relaxed) == expectedAttempts)
    }

    // Each failure used to add a call frame until an element arrived; a loop keeps it flat.
    @Test(.timeLimit(.minutes(1))) func retryOnAnErrorTypeYieldsAfterTenThousandConsecutiveFailures() async throws {
        struct Refused: Error, Equatable {}
        /// Throws on each of the first `failures` attempts, then yields 42 and finishes.
        struct FailsThenYields: AsyncSequence, Sendable {
            let failures: Int
            let attempts: ManagedAtomic<Int>
            struct AsyncIterator: AsyncIteratorProtocol {
                let failures: Int
                let attempts: ManagedAtomic<Int>
                var finished = false
                mutating func next() async throws -> Int? {
                    guard !finished else { return nil }
                    if attempts.loadThenWrappingIncrement(ordering: .relaxed) < failures {
                        throw Refused()
                    }
                    finished = true
                    return 42
                }
            }
            func makeAsyncIterator() -> AsyncIterator {
                AsyncIterator(failures: failures, attempts: attempts)
            }
        }
        let failures = 10_000
        let attempts = ManagedAtomic(0)
        let upstream = FailsThenYields(failures: failures, attempts: attempts)
        let expected: [Int] = [42]
        let expectedAttempts = failures + 1

        var received = [Int]()
        for try await element in upstream.retry(UInt(failures), on: Refused.self) {
            received.append(element)
        }

        #expect(received == expected)
        #expect(attempts.load(ordering: .relaxed) == expectedAttempts)
    }

    // Each failure used to add a call frame until an element arrived; a loop keeps it flat.
    @Test(.timeLimit(.minutes(1))) func retryAfterFlatMappingYieldsAfterTenThousandConsecutiveFailures() async throws {
        struct Refused: Error, Equatable {}
        /// Throws on each of the first `failures` attempts, then yields 42 and finishes.
        struct FailsThenYields: AsyncSequence, Sendable {
            let failures: Int
            let attempts: ManagedAtomic<Int>
            struct AsyncIterator: AsyncIteratorProtocol {
                let failures: Int
                let attempts: ManagedAtomic<Int>
                var finished = false
                mutating func next() async throws -> Int? {
                    guard !finished else { return nil }
                    if attempts.loadThenWrappingIncrement(ordering: .relaxed) < failures {
                        throw Refused()
                    }
                    finished = true
                    return 42
                }
            }
            func makeAsyncIterator() -> AsyncIterator {
                AsyncIterator(failures: failures, attempts: attempts)
            }
        }
        let failures = 10_000
        let attempts = ManagedAtomic(0)
        let upstream = FailsThenYields(failures: failures, attempts: attempts)
        let expected: [Int] = [42]
        let expectedAttempts = failures + 1

        var received = [Int]()
        for try await element in upstream.retry(UInt(failures), { _ in [Int]().async }) {
            received.append(element)
        }

        #expect(received == expected)
        #expect(attempts.load(ordering: .relaxed) == expectedAttempts)
    }

    // Each failure used to add a call frame until an element arrived; a loop keeps it flat.
    @Test(.timeLimit(.minutes(1))) func retryOnAnErrorAfterFlatMappingYieldsAfterTenThousandConsecutiveFailures() async throws {
        struct Refused: Error, Equatable {}
        /// Throws on each of the first `failures` attempts, then yields 42 and finishes.
        struct FailsThenYields: AsyncSequence, Sendable {
            let failures: Int
            let attempts: ManagedAtomic<Int>
            struct AsyncIterator: AsyncIteratorProtocol {
                let failures: Int
                let attempts: ManagedAtomic<Int>
                var finished = false
                mutating func next() async throws -> Int? {
                    guard !finished else { return nil }
                    if attempts.loadThenWrappingIncrement(ordering: .relaxed) < failures {
                        throw Refused()
                    }
                    finished = true
                    return 42
                }
            }
            func makeAsyncIterator() -> AsyncIterator {
                AsyncIterator(failures: failures, attempts: attempts)
            }
        }
        let failures = 10_000
        let attempts = ManagedAtomic(0)
        let upstream = FailsThenYields(failures: failures, attempts: attempts)
        let expected: [Int] = [42]
        let expectedAttempts = failures + 1

        var received = [Int]()
        for try await element in upstream.retry(UInt(failures), on: Refused(), { _ in [Int]().async }) {
            received.append(element)
        }

        #expect(received == expected)
        #expect(attempts.load(ordering: .relaxed) == expectedAttempts)
    }

    // Each failure used to add a call frame until an element arrived; a loop keeps it flat.
    @Test(.timeLimit(.minutes(1))) func retryOnAnErrorTypeAfterFlatMappingYieldsAfterTenThousandConsecutiveFailures() async throws {
        struct Refused: Error, Equatable {}
        /// Throws on each of the first `failures` attempts, then yields 42 and finishes.
        struct FailsThenYields: AsyncSequence, Sendable {
            let failures: Int
            let attempts: ManagedAtomic<Int>
            struct AsyncIterator: AsyncIteratorProtocol {
                let failures: Int
                let attempts: ManagedAtomic<Int>
                var finished = false
                mutating func next() async throws -> Int? {
                    guard !finished else { return nil }
                    if attempts.loadThenWrappingIncrement(ordering: .relaxed) < failures {
                        throw Refused()
                    }
                    finished = true
                    return 42
                }
            }
            func makeAsyncIterator() -> AsyncIterator {
                AsyncIterator(failures: failures, attempts: attempts)
            }
        }
        let failures = 10_000
        let attempts = ManagedAtomic(0)
        let upstream = FailsThenYields(failures: failures, attempts: attempts)
        let expected: [Int] = [42]
        let expectedAttempts = failures + 1

        var received = [Int]()
        for try await element in upstream.retry(UInt(failures), on: Refused.self, { _ in [Int]().async }) {
            received.append(element)
        }

        #expect(received == expected)
        #expect(attempts.load(ordering: .relaxed) == expectedAttempts)
    }
}
