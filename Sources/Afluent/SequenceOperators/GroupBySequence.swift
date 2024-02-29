//
//  GroupBySequence.swift
//
//
//  Created by Trip Phillips on 2/29/24.
//

import Foundation

extension AsyncSequences {
    public struct GroupBy<Upstream: AsyncSequence, Key: Hashable>: AsyncSequence {
        public typealias Element = Upstream.Element
        let upstream: Upstream
        let keySelector: (Element) async -> Key
        
        lazy var iterator = upstream.makeAsyncIterator()
        
        init(upstream: Upstream, keySelector: @escaping (Element) async -> Key) {
            self.upstream = upstream
            self.keySelector = keySelector
        }
        
        public struct AsyncIterator: AsyncIteratorProtocol {
            let upstream: Upstream
            let keySelector: (Element) async -> Key
            
            public mutating func next() async throws -> Element? {
                return nil
            }
        }
        
        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(upstream: upstream, keySelector: keySelector)
        }
    }
}

extension AsyncSequence {
    public func groupBy<Key: Hashable>(keySelector: @escaping (Element) async -> Key) -> AsyncSequences.GroupBy<Self, Key> {
        AsyncSequences.GroupBy(upstream: self, keySelector: keySelector)
    }
}
