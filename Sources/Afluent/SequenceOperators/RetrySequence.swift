//
//  RetrySequence.swift
//
//
//  Created by Tyler Thompson on 11/28/23.
//

import Foundation

extension AsyncSequences {
    public final actor Retry<Upstream: AsyncSequence>: AsyncSequence, AsyncIteratorProtocol {
        public typealias Element = Upstream.Element
        let upstream: Upstream
        var retries: UInt
        lazy var iterator = upstream.makeAsyncIterator()

        init(upstream: Upstream, retries: UInt) {
            self.upstream = upstream
            self.retries = retries
        }

        public func next() async throws -> Upstream.Element? {
            do {
                try Task.checkCancellation()
                var copy = iterator
                let next = try await copy.next()
                iterator = copy
                return next
            } catch {
                guard !(error is CancellationError) else { throw error }

                if retries > 0 {
                    retries -= 1
                    iterator = upstream.makeAsyncIterator()
                    return try await next()
                } else {
                    throw error
                }
            }
        }

        public nonisolated func makeAsyncIterator() -> Retry<Upstream> { self }
    }

    public final actor RetryOn<Upstream: AsyncSequence, Failure: Error & Equatable>: AsyncSequence, AsyncIteratorProtocol {
        public typealias Element = Upstream.Element
        let upstream: Upstream
        var retries: UInt
        let error: Failure
        lazy var iterator = upstream.makeAsyncIterator()

        init(upstream: Upstream, retries: UInt, error: Failure) {
            self.upstream = upstream
            self.retries = retries
            self.error = error
        }

        public func next() async throws -> Upstream.Element? {
            do {
                try Task.checkCancellation()
                var copy = iterator
                let next = try await copy.next()
                iterator = copy
                return next
            } catch (let err) {
                guard !(err is CancellationError) else { throw err }

                guard let unwrappedError = (err as? Failure),
                      unwrappedError == error else {
                    throw err
                }
                if retries > 0 {
                    retries -= 1
                    iterator = upstream.makeAsyncIterator()
                    return try await next()
                } else {
                    throw error
                }
            }
        }

        public nonisolated func makeAsyncIterator() -> RetryOn<Upstream, Failure> { self }
    }
}

extension AsyncSequence {
    /// Retries the upstream `AsyncSequence` up to a specified number of times.
    ///
    /// - Parameter retries: The maximum number of times to retry the upstream, defaulting to 1.
    ///
    /// - Returns: An `AsyncSequence` that emits the same output as the upstream but retries on failure up to the specified number of times.
    /// - Important: Not every `AsyncSequence` can be retried, for this to work the sequence has to implement an iterator that doesn't preserve state across various creations.
    /// - Note: `AsyncStream` and `AsyncThrowingStream` are notable sequences which cannot be retried on their own.
    public func retry(_ retries: UInt = 1) -> AsyncSequences.Retry<Self> {
        AsyncSequences.Retry(upstream: self, retries: retries)
    }

    /// Retries the upstream `AsyncSequence` up to a specified number of times only when a specific error occurs.
    ///
    /// - Parameters:
    ///   - retries: The maximum number of times to retry the upstream, defaulting to 1.
    ///   - error: The specific error that should trigger a retry.
    ///
    /// - Returns: An `AsyncSequence` that emits the same output as the upstream but retries on the specified error up to the specified number of times.
    /// - Important: Not every `AsyncSequence` can be retried, for this to work the sequence has to implement an iterator that doesn't preserve state across various creations.
    /// - Note: `AsyncStream` and `AsyncThrowingStream` are notable sequences which cannot be retried on their own.
    public func retry<E: Error & Equatable>(_ retries: UInt = 1, on error: E) -> AsyncSequences.RetryOn<Self, E> {
        AsyncSequences.RetryOn(upstream: self, retries: retries, error: error)
    }
}
