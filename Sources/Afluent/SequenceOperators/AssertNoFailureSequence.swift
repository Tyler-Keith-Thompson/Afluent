//
//  AssertNoFailureSequence.swift
//
//
//  Created by Tyler Thompson on 12/10/23.
//

import Foundation

extension AsyncSequences {
    /// An async sequence that raises a fatal error if its upstream sequence throws.
    ///
    /// Used as the implementation detail for ``AsyncSequence/assertNoFailure()``.
    public struct AssertNoFailure<Upstream: AsyncSequence & Sendable>: AsyncSequence, Sendable {
        public typealias Element = Upstream.Element
        let upstream: Upstream

        public struct AsyncIterator: AsyncIteratorProtocol {
            var upstreamIterator: Upstream.AsyncIterator

            public mutating func next() async throws -> Element? {
                do {
                    try Task.checkCancellation()
                    return try await upstreamIterator.next()
                } catch {
                    guard !(error is CancellationError) else { throw error }

                    fatalError(String(describing: error))
                }
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(upstreamIterator: upstream.makeAsyncIterator())
        }
    }
}

extension AsyncSequence where Self: Sendable {
    /// Raises a fatal error if the upstream async sequence throws (other than cancellation), otherwise republishes all received values.
    ///
    /// Use this to assert that a sequence is infallible, propagating values and terminating with a fatal error if any error occurs.
    ///
    /// ## Example
    /// ```
    /// let numbers = AsyncStream<Int> { continuation in
    ///     continuation.yield(1)
    ///     continuation.yield(2)
    ///     continuation.finish()
    /// }
    /// for try await value in numbers.assertNoFailure() {
    ///     print(value)
    /// }
    /// ```
    public func assertNoFailure() -> AsyncSequences.AssertNoFailure<Self> {
        AsyncSequences.AssertNoFailure(upstream: self)
    }
}
