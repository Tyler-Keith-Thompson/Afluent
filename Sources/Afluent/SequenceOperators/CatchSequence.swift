//
//  CatchSequence.swift
//
//
//  Created by Tyler Thompson on 11/28/23.
//

import Foundation

extension AsyncSequences {
    public struct Catch<Upstream: AsyncSequence, Downstream: AsyncSequence>: AsyncSequence where Upstream.Element == Downstream.Element {
        public typealias Element = Upstream.Element
        let upstream: Upstream
        let handler: @Sendable (Error) async throws -> Downstream

        init(upstream: Upstream, @_inheritActorContext @_implicitSelfCapture _ handler: @escaping @Sendable (Error) async throws -> Downstream) {
            self.upstream = upstream
            self.handler = handler
        }

        public struct AsyncIterator: AsyncIteratorProtocol {
            var upstreamIterator: Upstream.AsyncIterator
            let handler: @Sendable (Error) async throws -> Downstream
            var caughtIterator: Downstream.AsyncIterator?

            public mutating func next() async throws -> Element? {
                if var caughtIterator {
                    return try await caughtIterator.next()
                }

                do {
                    try Task.checkCancellation()
                    return try await upstreamIterator.next()
                } catch {
                    guard !(error is CancellationError) else { throw error }
                    caughtIterator = try await handler(error).makeAsyncIterator()
                    return try await next()
                }
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(upstreamIterator: upstream.makeAsyncIterator(),
                          handler: handler)
        }
    }
}

extension AsyncSequence {
    /// Catches any errors emitted by the upstream `AsyncSequence` and handles them using the provided closure.
    ///
    /// - Parameters:
    ///   - handler: A closure that takes an `Error` and returns an `AsyncSequence`.
    ///
    /// - Returns: An `AsyncSequence` that will catch and handle any errors emitted by the upstream sequence.
    public func `catch`<D: AsyncSequence>(@_inheritActorContext @_implicitSelfCapture _ handler: @escaping @Sendable (Error) async -> D) -> AsyncSequences.Catch<Self, D> {
        AsyncSequences.Catch(upstream: self, handler)
    }

    /// Catches a specific type of error emitted by the upstream `AsyncSequence` and handles them using the provided closure.
    ///
    /// - Parameters:
    ///   - error: The specific error type to catch.
    ///   - handler: A closure that takes an `Error` and returns an `AsyncSequence`.
    ///
    /// - Returns: An `AsyncSequence` that will catch and handle the specific error.
    public func `catch`<D: AsyncSequence, E: Error & Equatable>(_ error: E, @_inheritActorContext @_implicitSelfCapture _ handler: @escaping @Sendable (E) async -> D) -> AsyncSequences.Catch<Self, D> {
        tryCatch { err in
            guard let unwrappedError = (err as? E),
                  unwrappedError == error else { throw err }
            return await handler(unwrappedError)
        }
    }

    /// Tries to catch any errors emitted by the upstream `AsyncSequence` and handles them using the provided throwing closure.
    ///
    /// - Parameters:
    ///   - handler: A closure that takes an `Error` and returns an `AsyncSequence`, potentially throwing an error.
    ///
    /// - Returns: An `AsyncSequence` that will try to catch and handle any errors emitted by the upstream sequence.
    public func tryCatch<D: AsyncSequence>(@_inheritActorContext @_implicitSelfCapture _ handler: @escaping @Sendable (Error) async throws -> D) -> AsyncSequences.Catch<Self, D> {
        AsyncSequences.Catch(upstream: self, handler)
    }

    /// Tries to catch a specific type of error emitted by the upstream `AsyncSequence` and handles them using the provided throwing closure.
    ///
    /// - Parameters:
    ///   - error: The specific error type to catch.
    ///   - handler: A closure that takes an `Error` and returns an `AsyncSequence`, potentially throwing an error.
    ///
    /// - Returns: An `AsyncSequence` that will try to catch and handle the specific error.
    public func tryCatch<D: AsyncSequence, E: Error & Equatable>(_ error: E, @_inheritActorContext @_implicitSelfCapture _ handler: @escaping @Sendable (E) async throws -> D) -> AsyncSequences.Catch<Self, D> {
        tryCatch { err in
            guard let unwrappedError = (err as? E),
                  unwrappedError == error else { throw err }
            return try await handler(unwrappedError)
        }
    }
}
