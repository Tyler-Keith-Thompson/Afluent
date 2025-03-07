//
//  OutputSequence.swift
//  Afluent
//
//  Created by Roman Temchenko on 2025-03-05.
//

import Foundation

extension AsyncSequences {
    public struct OutputOne<Upstream: AsyncSequence & Sendable>: AsyncSequence, Sendable {
        public typealias Element = Upstream.Element
        let upstream: Upstream
        let index: Int

        public struct AsyncIterator: AsyncIteratorProtocol {
            var upstreamIterator: Upstream.AsyncIterator
            let index: Int
            var finished = false
            var nextIndex = 0

            public mutating func next() async throws -> Element? {
                try Task.checkCancellation()
                guard !finished else { return nil }
                while let next = try await upstreamIterator.next() {
                    try Task.checkCancellation()
                    if nextIndex == index {
                        defer { finished = true }
                        return next
                    }
                    nextIndex += 1
                }
                defer { finished = true }
                return nil
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(upstreamIterator: upstream.makeAsyncIterator(), index: index)
        }
    }
    
}

extension AsyncSequence where Self: Sendable {

    public func output(at index: Int) -> AsyncSequences.OutputOne<Self> {
        AsyncSequences.OutputOne(upstream: self, index: index)
    }
    
}
