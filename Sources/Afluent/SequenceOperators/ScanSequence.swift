//
//  ScanSequence.swift
//  Afluent
//
//  Created by Tyler Thompson on 6/14/25.
//

import Foundation

extension AsyncSequences {
    public struct Scan<Upstream: AsyncSequence & Sendable, Output: Sendable>: AsyncSequence, Sendable
    where Upstream.Element: Sendable {
        public typealias Element = Output

        let upstream: Upstream
        let initialResult: Output
        let nextPartialResult: @Sendable (Output, Upstream.Element) async throws -> Output

        public struct AsyncIterator: AsyncIteratorProtocol {
            var upstream: Upstream.AsyncIterator
            let nextPartialResult: @Sendable (Output, Upstream.Element) async throws -> Output
            private var nextResult: Output

            init(upstream: Upstream.AsyncIterator, initialResult: Output, nextPartialResult: @Sendable @escaping (Output, Upstream.Element) async throws -> Output) {
                self.upstream = upstream
                self.nextResult = initialResult
                self.nextPartialResult = nextPartialResult
            }
            
            public mutating func next() async throws -> Element? {
                try Task.checkCancellation()
                guard let upstreamNext = try await upstream.next() else { return nil }
                nextResult = try await nextPartialResult(nextResult, upstreamNext)
                return nextResult
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(upstream: upstream.makeAsyncIterator(), initialResult: initialResult, nextPartialResult: nextPartialResult)
        }
    }
}

extension AsyncSequence where Self: Sendable {
    /// Accumulates state over the elements of an asynchronous sequence, emitting each intermediate accumulated value.
    ///
    /// This operator works similarly to Combine's `scan` operator. It produces a sequence of values by repeatedly combining a running
    /// accumulated value with each new element from the upstream async sequence using the provided closure.
    ///
    /// This is useful for computing running totals, aggregating state, or applying stateful transformations over time.
    ///
    /// ## Example
    /// The following example demonstrates accumulating a running sum over an asynchronous sequence of integers:
    /// ```swift
    /// // An async sequence producing the numbers 1 through 5
    /// let numbers = AsyncStream<Int> { continuation in
    ///     for i in 1...5 {
    ///         continuation.yield(i)
    ///     }
    ///     continuation.finish()
    /// }
    ///
    /// // Use scan to accumulate a running sum
    /// let runningSum = numbers.scan(0) { partialSum, nextNumber in
    ///     return partialSum + nextNumber
    /// }
    ///
    /// // Consume the running sums
    /// Task {
    ///     for try await sum in runningSum {
    ///         print(sum) // Prints: 1, 3, 6, 10, 15
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - initialResult: The initial accumulated value to start with.
    ///   - nextPartialResult: A closure that takes the current accumulated value and the next element from the upstream sequence,
    ///                        and returns a new accumulated value asynchronously.
    /// - Returns: An asynchronous sequence that produces each intermediate accumulated result.
    public func scan<T>(_ initialResult: T, _ nextPartialResult: @Sendable @escaping (T, Self.Element) async throws -> T) -> AsyncSequences.Scan<Self, T> {
        .init(upstream: self, initialResult: initialResult, nextPartialResult: nextPartialResult)
    }
}
