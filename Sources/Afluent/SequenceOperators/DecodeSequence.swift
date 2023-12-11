//
//  DecodeSequence.swift
//
//
//  Created by Tyler Thompson on 12/10/23.
//

import Foundation

extension AsyncSequences {
    public struct Decode<Upstream: AsyncSequence, Decoder: TopLevelDecoder, DecodedType: Decodable>: AsyncSequence where Upstream.Element == Decoder.Input {
        public typealias Element = DecodedType
        let upstream: Upstream
        let decoder: Decoder

        public struct AsyncIterator: AsyncIteratorProtocol {
            var upstreamIterator: Upstream.AsyncIterator
            let decoder: Decoder

            public mutating func next() async throws -> Element? {
                try Task.checkCancellation()
                return try await upstreamIterator.next().flatMap {
                    try decoder.decode(DecodedType.self, from: $0)
                }
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(upstreamIterator: upstream.makeAsyncIterator(), decoder: decoder)
        }
    }
}

extension AsyncSequence {
    /// Decodes the output from the upstream using a specified decoder.
    public func decode<T: Decodable, D: TopLevelDecoder>(type _: T.Type, decoder: D) -> AsyncSequences.Decode<Self, D, T> where Element == D.Input {
        AsyncSequences.Decode(upstream: self, decoder: decoder)
    }
}
