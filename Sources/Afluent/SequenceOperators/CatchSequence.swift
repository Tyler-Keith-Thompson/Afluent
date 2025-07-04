//
//  CatchSequence.swift
//
//
//  Created by Tyler Thompson on 11/28/23.
//

import Foundation

extension AsyncSequences {
    /// Used as the implementation detail for the catch/tryCatch sequence operators.
    public struct Catch<Upstream: AsyncSequence & Sendable, Downstream: AsyncSequence & Sendable>:
        AsyncSequence, Sendable
    where Upstream.Element == Downstream.Element {
        public typealias Element = Upstream.Element
        let upstream: Upstream
        let handler: @Sendable (Error) async throws -> Downstream

        init(
            upstream: Upstream,
            @_inheritActorContext @_implicitSelfCapture _ handler: @Sendable @escaping (Error)
                async throws -> Downstream
        ) {
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
            AsyncIterator(
                upstreamIterator: upstream.makeAsyncIterator(),
                handler: handler)
        }
    }
}

extension AsyncSequence where Self: Sendable {
    /// Catches any errors emitted by the upstream `AsyncSequence` and handles them using the provided closure.
    ///
    /// ## Example
    /// ```swift
    /// for try await value in Just(1).catch { _ in Just(0) } {
    ///     print(value)
    /// }
    /// ```
    public func `catch`<D: AsyncSequence>(
        @_inheritActorContext @_implicitSelfCapture _ handler: @Sendable @escaping (Error) async ->
            D
    ) -> AsyncSequences.Catch<Self, D> {
        AsyncSequences.Catch(upstream: self, handler)
    }

    /// Catches a specific type of error emitted by the upstream `AsyncSequence` and handles them using the provided closure.
    ///
    /// ## Example
    /// ```swift
    /// for try await value in Just(1).catch(MyError()) { _ in Just(0) } {
    ///     print(value)
    /// }
    /// ```
    public func `catch`<D: AsyncSequence, E: Error & Equatable>(
        _ error: E,
        @_inheritActorContext @_implicitSelfCapture _ handler: @Sendable @escaping (E) async -> D
    ) -> AsyncSequences.Catch<Self, D> {
        tryCatch { err in
            guard let unwrappedError = (err as? E),
                unwrappedError == error
            else { throw err }
            return await handler(unwrappedError)
        }
    }

    /// Tries to catch any errors emitted by the upstream `AsyncSequence` and handles them using the provided throwing closure.
    ///
    /// ## Example
    /// ```swift
    /// for try await value in Just(1).tryCatch { _ in Just(0) } {
    ///     print(value)
    /// }
    /// ```
    public func tryCatch<D: AsyncSequence>(
        @_inheritActorContext @_implicitSelfCapture _ handler: @Sendable @escaping (Error)
            async throws -> D
    ) -> AsyncSequences.Catch<Self, D> {
        AsyncSequences.Catch(upstream: self, handler)
    }

    /// Tries to catch a specific type of error emitted by the upstream `AsyncSequence` and handles them using the provided throwing closure.
    ///
    /// ## Example
    /// ```swift
    /// for try await value in Just(1).tryCatch(MyError()) { _ in Just(0) } {
    ///     print(value)
    /// }
    /// ```
    public func tryCatch<D: AsyncSequence, E: Error & Equatable>(
        _ error: E,
        @_inheritActorContext @_implicitSelfCapture _ handler: @Sendable @escaping (E) async throws
            -> D
    ) -> AsyncSequences.Catch<Self, D> {
        tryCatch { err in
            guard let unwrappedError = (err as? E),
                unwrappedError == error
            else { throw err }
            return try await handler(unwrappedError)
        }
    }
}
