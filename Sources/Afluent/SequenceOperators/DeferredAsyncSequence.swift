//
//  DeferredAsyncSequence.swift
//
//
//  Created by Annalise Mariottini on 12/20/23.
//

import Foundation

/// An asynchronous sequence that defers the execution of another asynchronous sequence until iteration.
///
/// Using this type allows for an asynchronous sequence to be created without eagerly beginning execution.
/// Notably, `AsyncStream` and `AsyncThrowingStream` immediately execute their passed closure to start yielding and buffering values.
/// By wrapping either of these in a `DeferredSequence`, you can define the creation of an asynchronous sequence without executing it immediately.
///
/// Each time iteration begins using this type, the passed closure is called to create a new asynchronous sequence.
/// This can allow for a sequence to be created and iterated over multiple times.
///
/// ```swift
/// let deferred = DeferredSequence {
///     AsyncStream { continuation in
///         // yield some values asynchronously
///     }
/// }
///
/// for try await value in deferred {
///     // starts at the first element
/// }
///
/// for try await value in deferred {
///     // starts at the first element
/// }
/// ```
public struct DeferredAsyncSequence<Upstream: AsyncSequence>: AsyncSequence {
    public typealias Element = Upstream.Element
    private let upstream: (() -> Upstream)

    /// Constructs an asynchronous sequence defining an closure that returns an asynchronous sequence
    /// that will later be called at the time of iteration.
    ///
    /// - Parameter upstream: A closure that returns an asynchronous sequence that will be used later during iteration.
    public init(upstream: @escaping (() -> Upstream)) {
        self.upstream = upstream
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        var upstreamIterator: Upstream.AsyncIterator

        public mutating func next() async throws -> Upstream.AsyncIterator.Element? {
            try Task.checkCancellation()
            return try await upstreamIterator.next()
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(upstreamIterator: upstream().makeAsyncIterator())
    }
}
