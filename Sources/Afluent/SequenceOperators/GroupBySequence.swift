//
//  GroupBySequence.swift
//
//
//  Created by Trip Phillips on 2/29/24.
//

import Foundation

extension AsyncSequences {
    /// Used as the implementation detail for the ``AsyncSequence/groupBy(keySelector:)`` operator.
    public struct GroupBy<Upstream: AsyncSequence & Sendable, Key: Hashable>: AsyncSequence,
        Sendable
    where Upstream.Element: Sendable {
        public typealias Element = (key: Key, stream: AsyncThrowingStream<Upstream.Element, Error>)
        let upstream: Upstream
        let keySelector: @Sendable (Upstream.Element) async -> Key

        init(upstream: Upstream, keySelector: @Sendable @escaping (Upstream.Element) async -> Key) {
            self.upstream = upstream
            self.keySelector = keySelector
        }

        public struct AsyncIterator: AsyncIteratorProtocol {
            var upstream: Upstream.AsyncIterator
            let keySelector: (Upstream.Element) async -> Key

            var keyedSequences = [
                Key: (
                    stream: AsyncThrowingStream<Upstream.Element, Error>,
                    continuation: AsyncThrowingStream<Upstream.Element, Error>.Continuation
                )
            ]()

            public mutating func next() async throws -> Element? {
                do {
                    try Task.checkCancellation()
                    guard let element = try await upstream.next() else {
                        try Task.checkCancellation()
                        keyedSequences.values.forEach { $0.continuation.finish() }
                        return nil
                    }
                    let key = await keySelector(element)
                    if let existing = keyedSequences[key] {
                        existing.continuation.yield(element)
                        return try await next()
                    } else {
                        let (stream, continuation) = AsyncThrowingStream<Upstream.Element, Error>
                            .makeStream()
                        keyedSequences[key] = (stream: stream, continuation: continuation)
                        defer { continuation.yield(element) }
                        return (key: key, stream: stream)
                    }
                } catch {
                    keyedSequences.values.forEach { $0.continuation.finish(throwing: error) }
                    throw error
                }
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(upstream: upstream.makeAsyncIterator(), keySelector: keySelector)
        }
    }
}

extension AsyncSequence where Self: Sendable, Element: Sendable {
    /// Groups the elements of the sequence into substreams based on a key.
    ///
    /// Use this to partition values by a computed key, yielding an async sequence for each group.
    ///
    /// - Warning: This operator stores each group in a dictionary. If the number of unique keys is very large or unbounded, memory usage may increase significantly.
    ///
    /// ## Example
    /// ```
    /// for await (key, group) in Just(1).groupBy { $0 % 2 } {
    ///     print("Key: \(key)")
    ///     for try await value in group {
    ///         print("Value: \(value)")
    ///     }
    /// }
    /// ```
    public func groupBy<Key: Hashable>(keySelector: @Sendable @escaping (Element) async -> Key)
        -> AsyncSequences.GroupBy<Self, Key>
    {
        AsyncSequences.GroupBy(upstream: self, keySelector: keySelector)
    }
}
