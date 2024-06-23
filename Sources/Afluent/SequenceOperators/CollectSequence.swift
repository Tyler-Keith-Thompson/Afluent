//
//  CollectSequence.swift
//
//
//  Created by Tyler Thompson on 12/23/23.
//

import Foundation

extension AsyncSequences {
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
    /// Collects all received elements, and emits a single array of the collection when the upstream sequence finishes.
    /// ### Discussion:
    /// Use `collect()` to gather elements into an array that the operator emits after the upstream sequence finishes.
    /// If the upstream sequence fails with an error, this sequence forwards the error to the downstream receiver instead of sending its output.
    /// - Important: Be cautious when using `collect` on sequences that can emit a large number of elements or do not complete, as it can lead to high memory usage or even memory exhaustion.
    public func collect() -> AsyncSequences.Collect<Self> {
        AsyncSequences.Collect(upstream: self)
    }
}
