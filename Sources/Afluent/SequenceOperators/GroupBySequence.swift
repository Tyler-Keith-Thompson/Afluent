//
//  GroupBySequence.swift
//
//
//  Created by Trip Phillips on 2/29/24.
//

import Foundation

extension AsyncSequences {
    public struct GroupBy<Upstream: AsyncSequence, Key: Hashable>: AsyncSequence {
        public typealias Element = GroupedSequence<Key, Upstream>
        let upstream: Upstream
        let keySelector: (Upstream.Element) async -> Key

        init(upstream: Upstream, keySelector: @escaping (Upstream.Element) async -> Key) {
            self.upstream = upstream
            self.keySelector = keySelector
        }
        
        public struct AsyncIterator: AsyncIteratorProtocol {
            public typealias Element = GroupedSequence<Key, Upstream>
            let upstream: Upstream
            let keySelector: (Upstream.Element) async -> Key
            
            lazy var iterator = upstream.makeAsyncIterator()
            
            public mutating func next() async throws -> AsyncIterator.Element? {
                try Task.checkCancellation()
                guard let element = try await iterator.next() else {
                    return nil
                }
                let key = await keySelector(element)
                return GroupedSequence(upstream: upstream, key: key)
            }
        }
        
        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(upstream: upstream, keySelector: keySelector)
        }
    }
    
    public struct GroupedSequence<Key: Hashable, Upstream: AsyncSequence>: AsyncSequence {
        
        public typealias Element = Upstream.Element
        let upstream: Upstream
        public let key: Key

        init(upstream: Upstream, key: Key) {
            self.upstream = upstream
            self.key = key
        }
        
        public struct AsyncIterator: AsyncIteratorProtocol {
            let upstream: Upstream
            
            lazy var iterator = upstream.makeAsyncIterator()
            
            public mutating func next() async throws -> Element? {
                try Task.checkCancellation()
                return try await iterator.next()
            }
        }
        
        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(upstream: upstream)
        }
    }
}

extension AsyncSequence {
    public func groupBy<Key: Hashable>(keySelector: @escaping (Element) async -> Key) -> AsyncSequences.GroupBy<Self, Key> {
        AsyncSequences.GroupBy(upstream: self, keySelector: keySelector)
    }
}
