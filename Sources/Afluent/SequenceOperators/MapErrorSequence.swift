//
//  MapErrorSequence.swift
//
//
//  Created by Tyler Thompson on 12/17/23.
//

import Foundation

extension AsyncSequences {
    /// Used as the implementation detail for the ``AsyncSequence/mapError(_:)`` operator.
    public struct MapError<Upstream: AsyncSequence & Sendable>: AsyncSequence, Sendable {
        public typealias Element = Upstream.Element
        let upstream: Upstream
        let transform: @Sendable (Error) -> Error

        public struct AsyncIterator: AsyncIteratorProtocol {
            var upstreamIterator: Upstream.AsyncIterator
            let transform: (Error) -> Error

            public mutating func next() async throws -> Element? {
                do {
                    try Task.checkCancellation()
                    return try await upstreamIterator.next()
                } catch {
                    throw transform(error)
                }
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(
                upstreamIterator: upstream.makeAsyncIterator(),
                transform: transform)
        }
    }
}

extension AsyncSequence where Self: Sendable {
    /// Transforms any error produced by the sequence using the provided closure.
    ///
    /// This is useful for converting between error types or adding additional context to errors.
    ///
    /// ## Example
    /// ```
    /// enum NetworkError: Error { case timeout }
    /// enum UserError: Error { case displayMessage(String) }
    /// let throwing = Just(1).map { _ in throw NetworkError.timeout }
    /// for try await _ in throwing.mapError { error in
    ///     if let netErr = error as? NetworkError, netErr == .timeout {
    ///         return UserError.displayMessage("Request timed out")
    ///     }
    ///     return error
    /// } {
    ///     // Will throw UserError.displayMessage("Request timed out")
    /// }
    /// ```
    public func mapError(_ transform: @Sendable @escaping (Error) -> Error)
        -> AsyncSequences.MapError<Self>
    {
        AsyncSequences.MapError(upstream: self, transform: transform)
    }

    /// Transforms a specific error value produced by the sequence using the provided closure.
    ///
    /// ## Example
    /// ```
    /// enum NetworkError: Error, Equatable { case timeout }
    /// enum UserError: Error { case displayMessage(String) }
    /// let throwing = Just(1).map { _ in throw NetworkError.timeout }
    /// for try await _ in throwing.mapError(NetworkError.timeout) { _ in UserError.displayMessage("Request timed out") } {
    ///     // Will throw UserError.displayMessage("Request timed out") if the error matched
    /// }
    /// ```
    public func mapError<E: Error & Equatable>(
        _ error: E, _ transform: @Sendable @escaping (Error) -> Error
    ) -> AsyncSequences.MapError<Self> {
        mapError {
            if let e = $0 as? E, e == error { return transform(e) }
            return $0
        }
    }
}

