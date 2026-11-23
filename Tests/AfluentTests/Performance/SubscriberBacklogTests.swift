//
//  SubscriberBacklogTests.swift
//  Afluent
//

import Afluent
import Testing

// A consumer that falls behind takes each buffered value under the subject's (or share's) lock, so the time limit
// catches a drain that costs more than amortized O(1) per value. The backlog is 500,000 32-byte values: drained in
// O(n²), each take shifting the rest, that is about 4 TB of copying, far past the limit on any machine, where an
// amortized O(1) drain takes seconds in debug. Smaller backlogs or 8-byte values copy fast enough to pass either way.
@Suite(.timeLimit(.minutes(1)))
struct SubscriberBacklogTests {
    @Test("A PassthroughSubject subscriber reads a backlog of 500,000 values sent before its first read, in order")
    func passthroughSubjectBacklog() async throws {
        let count = 500_000
        let subject = PassthroughSubject<SIMD4<Int64>>()
        var sut = subject.makeAsyncIterator()
        for value in 0..<Int64(count) { subject.send(SIMD4(value, 0, 0, 0)) }
        subject.send(completion: .finished)
        let expected = (0..<Int64(count)).map { SIMD4($0, 0, 0, 0) }

        var actual = [SIMD4<Int64>]()
        actual.reserveCapacity(count)
        while let value = try await sut.next() { actual.append(value) }

        #expect(actual == expected)
    }

    @Test("A share() consumer that reads only after another drained the upstream gets its 500,000 values in order")
    func shareSlowConsumerBacklog() async {
        let count = 500_000
        let upstream = AsyncStream<SIMD4<Int64>> { continuation in
            for value in 0..<Int64(count) { continuation.yield(SIMD4(value, 0, 0, 0)) }
            continuation.finish()
        }
        let shared = upstream.share()
        let expected = (0..<Int64(count)).map { SIMD4($0, 0, 0, 0) }
        var slow = shared.makeAsyncIterator()
        var fast = shared.makeAsyncIterator()
        var fastValues = [SIMD4<Int64>]()
        fastValues.reserveCapacity(count)
        while let value = await fast.next() { fastValues.append(value) }

        var actual = [SIMD4<Int64>]()
        actual.reserveCapacity(count)
        while let value = await slow.next() { actual.append(value) }

        #expect(fastValues == expected)
        #expect(actual == expected)
    }
}
