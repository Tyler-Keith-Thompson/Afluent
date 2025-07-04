//
//  ReplaceNilSequence.swift
//
//
//  Created by Tyler Thompson on 12/17/23.
//

import Foundation

extension AsyncSequences {
    /// Used as the implementation detail for the ``AsyncSequence/replaceNil(with:)`` operator.
    public struct ReplaceNil<Upstream: AsyncSequence & Sendable, Output: Sendable>: AsyncSequence,
        Sendable
    where Upstream.Element == Output? {
        public typealias Element = Upstream.Element
        let upstream: Upstream
        let newOutput: Output

        public struct AsyncIterator: AsyncIteratorProtocol {
            var upstreamIterator: Upstream.AsyncIterator
            let newOutput: Output

            public mutating func next() async throws -> Element? {
                try Task.checkCancellation()
                switch try await upstreamIterator.next() {
                    case .none: return nil
                    case .some(.none): return newOutput
                    case .some(.some(let output)): return output
                }
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(
                upstreamIterator: upstream.makeAsyncIterator(),
                newOutput: newOutput)
        }
    }
}

extension AsyncSequence where Self: Sendable {
    /// Replaces any `nil` values from the sequence with the provided non-nil value.
    ///
    /// Use this to emit a fallback value whenever the upstream emits `nil`.
    ///
    /// ## Example
    /// ```swift
    /// let stream = AsyncStream<Int?> { continuation in
    ///     continuation.yield(1)
    ///     continuation.yield(nil)
    ///     continuation.yield(3)
    ///     continuation.finish()
    /// }
    /// for await value in stream.replaceNil(with: 42) {
    ///     print(value) // Prints: 1, 42, 3
    /// }
    /// ```
    public func replaceNil<E>(with value: E) -> AsyncSequences.ReplaceNil<Self, E>
    where Element == E? {
        AsyncSequences.ReplaceNil(upstream: self, newOutput: value)
    }
}

