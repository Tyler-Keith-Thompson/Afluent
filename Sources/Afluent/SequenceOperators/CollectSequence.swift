//
//  CollectSequence.swift
//
//
//  Created by Tyler Thompson on 12/23/23.
//

import Foundation

extension AsyncSequences {
    /// Used as the implementation detail for the ``AsyncSequence/collect()`` operator.
    public struct Collect<Upstream: AsyncSequence & Sendable>: AsyncSequence, Sendable {
        public typealias Element = [Upstream.Element]
        let upstream: Upstream

        public struct AsyncIterator: AsyncIteratorProtocol {
            var upstreamIterator: Upstream.AsyncIterator
            var collected = Element()
            var finished = false

            public mutating func next() async throws -> Element? {
                try Task.checkCancellation()
                guard !finished else { return nil }
                while let next = try await upstreamIterator.next() {
                    try Task.checkCancellation()
                    collected.append(next)
                }
                defer { finished = true }
                return collected
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(upstreamIterator: upstream.makeAsyncIterator())
        }
    }
}

extension AsyncSequence where Self: Sendable {
    /// Collects all received elements and emits a single array when the upstream sequence finishes.
    ///
    /// Use `collect()` to gather elements into an array and emit the result as a single value.
    /// If the upstream sequence fails with an error, the error is forwarded and no array is emitted.
    ///
    /// - Important: Be cautious using `collect()` on sequences that emit a large number of elements or never complete, as this can lead to high memory usage.
    ///
    /// ## Example
    /// ```swift
    /// for try await values in Just(1).collect() {
    ///     print(values) // Prints: [1]
    /// }
    /// ```
    public func collect() -> AsyncSequences.Collect<Self> {
        AsyncSequences.Collect(upstream: self)
    }
}
