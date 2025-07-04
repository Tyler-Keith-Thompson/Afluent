//
//  ReplaceErrorSequence.swift
//
//
//  Created by Tyler Thompson on 12/17/23.
//

import Foundation

extension AsyncSequences {
    /// Used as the implementation detail for the ``AsyncSequence/replaceError(with:)`` operator.
    public struct ReplaceError<Upstream: AsyncSequence & Sendable, Output: Sendable>: AsyncSequence,
        Sendable
    where Upstream.Element == Output {
        public typealias Element = Upstream.Element
        let upstream: Upstream
        let newOutput: Output

        public struct AsyncIterator: AsyncIteratorProtocol {
            var upstreamIterator: Upstream.AsyncIterator
            let newOutput: Output

            public mutating func next() async throws -> Element? {
                do {
                    try Task.checkCancellation()
                    return try await upstreamIterator.next()
                } catch {
                    guard !(error is CancellationError) else { throw error }
                    return newOutput
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
    /// Replaces any error from the sequence with the provided value.
    ///
    /// Use this to emit a fallback value instead of propagating an error downstream.
    ///
    /// ## Example
    /// ```swift
    /// let stream = Just(1).map { _ in throw MyError() }
    /// for await value in stream.replaceError(with: 42) {
    ///     print(value) // Prints: 42
    /// }
    /// ```
    public func replaceError(with value: Element) -> AsyncSequences.ReplaceError<Self, Element>
    where Element: Sendable {
        AsyncSequences.ReplaceError(upstream: self, newOutput: value)
    }
}
