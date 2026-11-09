//
//  DecodeSequence.swift
//
//
//  Created by Tyler Thompson on 12/10/23.
//

import Foundation

extension AsyncSequences {
    /// Used as the implementation detail for the ``_Concurrency/AsyncSequence/decode(type:decoder:)`` operator.
    public struct Decode<
        Upstream: AsyncSequence & Sendable, Decoder: TopLevelDecoder,
        DecodedType: Decodable & Sendable
    >: AsyncSequence, Sendable where Upstream.Element == Decoder.Input {
        public typealias Element = DecodedType

        let upstream: Upstream
        private let decode: SynchronizedFunction<Upstream.Element, DecodedType>

        init(upstream: Upstream, decoder: Decoder) {
            self.upstream = upstream
            decode = SynchronizedFunction { try decoder.decode(DecodedType.self, from: $0) }
        }

        public struct AsyncIterator: AsyncIteratorProtocol {
            var upstreamIterator: Upstream.AsyncIterator
            let decode: SynchronizedFunction<Upstream.Element, DecodedType>

            public mutating func next() async throws -> Element? {
                try Task.checkCancellation()
                return try await upstreamIterator.next().flatMap {
                    try decode($0)
                }
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(
                upstreamIterator: upstream.makeAsyncIterator(),
                decode: decode)
        }
    }
}

extension AsyncSequence where Self: Sendable {
    /// Decodes the output from the upstream using a specified decoder.
    ///
    /// Use this to decode values from upstream elements (such as encoded JSON) to a concrete type.
    ///
    /// ## Example
    /// ```swift
    /// struct Person: Decodable { let name: String }
    /// let json = try JSONEncoder().encode(Person(name: "Alice"))
    /// for try await person in Just(json).decode(type: Person.self, decoder: JSONDecoder()) {
    ///     print(person.name) // Prints: Alice
    /// }
    /// ```
    public func decode<T: Decodable, D: TopLevelDecoder>(type _: T.Type, decoder: D)
        -> AsyncSequences.Decode<Self, D, T> where Element == D.Input
    {
        AsyncSequences.Decode(upstream: self, decoder: decoder)
    }
}

