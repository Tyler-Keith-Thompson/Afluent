//
//  EncodeSequence.swift
//
//
//  Created by Tyler Thompson on 12/10/23.
//

import Foundation

extension AsyncSequences {
    /// Used as the implementation detail for the ``_Concurrency/AsyncSequence/encode(encoder:)`` operator.
    public struct Encode<Upstream: AsyncSequence & Sendable, Encoder: TopLevelEncoder>:
        AsyncSequence, Sendable
    where Upstream.Element: Encodable {
        public typealias Element = Encoder.Output

        let upstream: Upstream
        let encode: SynchronizedFunction<Upstream.Element, Element>

        init(upstream: Upstream, encoder: Encoder) {
            self.upstream = upstream
            encode = SynchronizedFunction { try encoder.encode($0) }
        }

        public struct AsyncIterator: AsyncIteratorProtocol {
            var upstreamIterator: Upstream.AsyncIterator
            let encode: SynchronizedFunction<Upstream.Element, Element>

            public mutating func next() async throws -> Element? {
                try Task.checkCancellation()
                return try await upstreamIterator.next().flatMap {
                    try encode($0)
                }
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(
                upstreamIterator: upstream.makeAsyncIterator(),
                encode: encode)
        }
    }
}

extension AsyncSequence where Self: Sendable {
    /// Encodes the output from upstream using the specified encoder.
    ///
    /// Use this to encode values into a data format (such as JSON) before further processing or output.
    ///
    /// ## Example
    /// ```swift
    /// struct Person: Encodable { let name: String }
    /// for try await data in Just(Person(name: "Alice")).encode(encoder: JSONEncoder()) {
    ///     print(data) // Encoded JSON data
    /// }
    /// ```
    public func encode<E: TopLevelEncoder>(encoder: E) -> AsyncSequences.Encode<Self, E>
    where Element: Encodable {
        AsyncSequences.Encode(upstream: self, encoder: encoder)
    }
}
