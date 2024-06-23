//
//  GroupBySequence.swift
//
//
//  Created by Trip Phillips on 2/29/24.
//

import Foundation

extension AsyncSequences {
    public struct GroupBy<Upstream: AsyncSequence & Sendable, Key: Hashable>: AsyncSequence, Sendable where Upstream.Element: Sendable {
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

            var keyedSequences = [Key: (stream: AsyncThrowingStream<Upstream.Element, Error>, continuation: AsyncThrowingStream<Upstream.Element, Error>.Continuation)]()

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
                        let (stream, continuation) = AsyncThrowingStream<Upstream.Element, Error>.makeStream()
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
    public func groupBy<Key: Hashable>(keySelector: @Sendable @escaping (Element) async -> Key) -> AsyncSequences.GroupBy<Self, Key> {
        AsyncSequences.GroupBy(upstream: self, keySelector: keySelector)
    }
}
