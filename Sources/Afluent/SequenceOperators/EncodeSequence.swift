//
//  EncodeSequence.swift
//
//
//  Created by Tyler Thompson on 12/10/23.
//

import Foundation

extension AsyncSequences {
    public struct Encode<Upstream: AsyncSequence & Sendable, Encoder: TopLevelEncoder & Sendable>: AsyncSequence, Sendable where Upstream.Element: Encodable {
        public typealias Element = Encoder.Output
        let upstream: Upstream
        let encoder: Encoder

        public struct AsyncIterator: AsyncIteratorProtocol {
            var upstreamIterator: Upstream.AsyncIterator
            let encoder: Encoder

            public mutating func next() async throws -> Element? {
                try Task.checkCancellation()
                return try await upstreamIterator.next().flatMap {
                    try encoder.encode($0)
                }
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(upstreamIterator: upstream.makeAsyncIterator(),
                          encoder: encoder)
        }
    }
}

extension AsyncSequence where Self: Sendable {
    /// Encodes the output from upstream using a specified encoder.
    public func encode<E: TopLevelEncoder>(encoder: E) -> AsyncSequences.Encode<Self, E> where Element: Encodable {
        AsyncSequences.Encode(upstream: self, encoder: encoder)
    }
}
