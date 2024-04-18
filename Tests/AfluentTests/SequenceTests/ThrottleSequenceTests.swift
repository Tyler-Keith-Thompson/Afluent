//
//  ThrottleSequenceTests.swift
//
//
//  Created by Trip Phillips on 2/12/24.
//

import Afluent
import Atomics
import Clocks
import ConcurrencyExtras
import Foundation
import Testing

@available(iOS 16.0, *)
struct ThrottleSequenceTests {
    enum TestError: Error {
        case upstreamError
    }

    actor ElementContainer {
        var elements = [Int]()

        func append(_ element: Int) {
            elements.append(element)
        }
    }

    @Test func testThrottleChecksForCancellation_whenLatestIsTrue() async throws {
        let testClock = TestClock()

        let stream = AsyncStream<Int> { continuation in
            continuation.finish()
        }.throttle(for: .milliseconds(10), clock: testClock, latest: true)

        let task = Task {
            for try await _ in stream { }
        }

        task.cancel()

        let result = await task.result

        #expect(throws: CancellationError.self) { try result.get() }
    }

    @Test func throttleChecksForCancellation_whenLatestIsFalse() async throws {
        let testClock = TestClock()

        let stream = AsyncStream<Int> { continuation in
            continuation.finish()
        }.throttle(for: .milliseconds(10), clock: testClock, latest: false)

        let task = Task {
            for try await _ in stream { }
        }

        task.cancel()

        let result = await task.result

        #expect(throws: CancellationError.self) { try result.get() }
    }

    @Test(arguments: [
        // LEGEND:
        // * 1, 2, 3, 4, 5, 6, 7, 8, 9 | Emit the values 1 through 9
        // * - | Wait 10 milliseconds (the full throttle duration) and assert
        // * ` | Wait 5 milliseconds (half the throttle duration) and assert
        // * e | Emit an error
        ("", ""),
        ("1", "1"),
        ("123", "13"),
        ("123e4", "13"),
        ("1-23", "1-3"),
        ("1-23-e4", "1-3"),
        ("123e", "13"),
        ("1-23456789", "1-9"),
        ("1-2-3-4-5-6-7-8-9", "1-2-3-4-5-6-7-8-9"),
        ("123-45-67-89", "13-5-7-9"),
        ("1-2345`6789", "1-9"),
        ("1``2``3``4``5``6``7``8``9", "1-2-3-4-5-6-7-8-9"),
        ("12345--6789", "15--9"),
        ("12345-67-89", "15-7-9"),
    ])
    func throttleWithLatestTrue(streamInput: String, expectedOutput: String) async throws {
        await withMainSerialExecutor {
            let (stream, continuation) = AsyncThrowingStream<Int, any Error>.makeStream()
            let testClock = TestClock()
            let test = ElementContainer()
            let throttledStream = stream.throttle(for: .milliseconds(10), clock: testClock, latest: true)
            Task {
                for try await el in throttledStream {
                    await test.append(el)
                }
            }
            let advancedDuration = ManagedAtomic<Int>(0)
            await parseThrottleDSL(streamInput: streamInput,
                                   expectedOutput: expectedOutput,
                                   testClock: testClock,
                                   advancedDuration: advancedDuration,
                                   continuation: continuation,
                                   test: test)
        }
    }

    @Test(arguments: [
        // LEGEND:
        // * 1, 2, 3, 4, 5, 6, 7, 8, 9 | Emit the values 1 through 9
        // * - | Wait 10 milliseconds (the full throttle duration) and assert
        // * ` | Wait 5 milliseconds (half the throttle duration) and assert
        // * e | Emit an error
        ("", ""),
        ("1", "1"),
        ("123", "12"),
        ("123e4", "12"),
        ("1-23", "1-2"),
        ("1-23-e4", "1-2"),
        ("123e", "12"),
        ("1-23456789", "1-2"),
        ("1-2-3-4-5-6-7-8-9", "1-2-3-4-5-6-7-8-9"),
        ("123-45-67-89", "12-4-6-8"),
        ("1-2345`6789", "1-2"),
        ("1``2``3``4``5``6``7``8``9", "1-2-3-4-5-6-7-8-9"),
        ("12345--6789", "12--6"),
        ("12345-67-89", "12-6-8"),
    ])
    func throttleWithLatestFalse(streamInput: String, expectedOutput: String) async throws {
        await withMainSerialExecutor {
            let (stream, continuation) = AsyncThrowingStream<Int, any Error>.makeStream()
            let testClock = TestClock()
            let test = ElementContainer()
            let throttledStream = stream.throttle(for: .milliseconds(10), clock: testClock, latest: false)
            Task {
                for try await el in throttledStream {
                    await test.append(el)
                }
            }
            let advancedDuration = ManagedAtomic<Int>(0)
            await parseThrottleDSL(streamInput: streamInput,
                                   expectedOutput: expectedOutput,
                                   testClock: testClock,
                                   advancedDuration: advancedDuration,
                                   continuation: continuation,
                                   test: test)
        }
    }

    fileprivate func parseThrottleDSL(streamInput: String, expectedOutput: String, testClock: TestClock<Duration>, advancedDuration: ManagedAtomic<Int>, continuation: AsyncThrowingStream<Int, any Error>.Continuation, test: ElementContainer) async {
        for (i, step) in streamInput.enumerated() {
            if step == "-" {
                await testClock.advance(by: .milliseconds(10))
                advancedDuration.wrappingIncrement(by: 10, ordering: .sequentiallyConsistent)
            } else if step == "`" {
                await testClock.advance(by: .milliseconds(5))
                advancedDuration.wrappingIncrement(by: 5, ordering: .sequentiallyConsistent)
            } else if let val = Int(String(step)) {
                continuation.yield(val)
            } else if step.lowercased() == "e" {
                continuation.yield(with: .failure(TestError.upstreamError))
            }

            let last = i == streamInput.count - 1

            // At every halt point, assert correct elements
            if step == "-" || step == "`" || last {
                if last {
                    await testClock.advance(by: .milliseconds(10))
                    advancedDuration.wrappingIncrement(by: 10, ordering: .sequentiallyConsistent)
                }
                _ = await Task {
                    let elements = await test.elements
                    var total = 0
                    // Parse the expected DSL, this is tricky because you have to sort of calculate how far in time to go to understand what the expected result is
                    var expected = expectedOutput.reduce(into: "") { partialResult, character in
                        guard total < advancedDuration.load(ordering: .sequentiallyConsistent) else { return }
                        if character == "-" {
                            total += 10
                        } else if character == "`" {
                            total += 5
                        }
                        partialResult.append(character)
                    }.compactMap { Int(String($0)) }
                    // after the first interval you have to wait for the full interval to have elapsed
                    if !(advancedDuration.load(ordering: .sequentiallyConsistent) % 10 == 0), advancedDuration.load(ordering: .sequentiallyConsistent) > 10, !last {
                        expected = Array(expected.dropLast())
                    }
                    #expect(elements == expected, "\(i) \(advancedDuration.load(ordering: .sequentiallyConsistent)) \(total)")
                }.result
            }
        }
        continuation.finish()
    }
}
