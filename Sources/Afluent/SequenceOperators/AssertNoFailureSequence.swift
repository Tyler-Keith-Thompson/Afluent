//
//  AssertNoFailureSequence.swift
//  
//
//  Created by Tyler Thompson on 12/10/23.
//

import Foundation
extension AsyncSequences {
    public struct AssertNoFailure<Upstream: AsyncSequence>: AsyncSequence {
        public typealias Element = Upstream.Element
        let upstream: Upstream

        public struct AsyncIterator: AsyncIteratorProtocol {
            var upstreamIterator: Upstream.AsyncIterator
            
            public mutating func next() async throws -> Element? {
                do {
                    try Task.checkCancellation()
                    return try await upstreamIterator.next()
                } catch {
                    guard !(error is CancellationError) else { throw error }

                    fatalError(String(describing: error))
                }
            }
        }
        
        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(upstreamIterator: upstream.makeAsyncIterator())
        }
    }
}

extension AsyncSequence {
    /// Raises a fatal error when its upstream sequence fails, and otherwise republishes all received input.
    public func assertNoFailure() -> AsyncSequences.AssertNoFailure<Self> {
        AsyncSequences.AssertNoFailure(upstream: self)
    }
}
