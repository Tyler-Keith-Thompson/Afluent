//
//  GroupBySequence.swift
//
//
//  Created by Trip Phillips on 2/29/24.
//

import Foundation

extension AsyncSequences {
    public struct GroupBy<Upstream: AsyncSequence, Key: Hashable>: AsyncSequence {
        public typealias Element = KeyedAsyncSequence<Key, Upstream>
        let upstream: Upstream
        let keySelector: (Upstream.Element) async -> Key
        
        init(upstream: Upstream, keySelector: @escaping (Upstream.Element) async -> Key) {
            self.upstream = upstream
            self.keySelector = keySelector
        }
        
        public struct AsyncIterator: AsyncIteratorProtocol {
            public typealias Element = KeyedAsyncSequence<Key, Upstream>
            var upstream: Upstream
            let keySelector: (Upstream.Element) async -> Key
            
            var keyedSequences = KeyedSequences()
            var iterator: AsyncThrowingStream<Element, Error>.Iterator?
            
            public mutating func next() async throws -> Element? {
                try Task.checkCancellation()
                if iterator == nil {
                    iterator = AsyncThrowingStream<Element, Error> { [upstream, keySelector, keyedSequences] continuation in
                        Task {
                            do {
                                for try await el in upstream {
                                    let key = await keySelector(el)
                                    if keyedSequences.sequences[key] != nil {
                                        let existingSequence = keyedSequences.sequences[key]
                                        existingSequence?.elements.append(el)
                                        keyedSequences.sequences[key] = existingSequence
                                    } else {
                                        let keyedAsyncSequence = KeyedAsyncSequence(upstream: upstream, elements: [el], key: key)
                                        keyedSequences.sequences[key] = keyedAsyncSequence
                                        continuation.yield(keyedAsyncSequence)
                                    }
                                }
                                
                                continuation.finish()
                            } catch {
                                continuation.finish(throwing: error)
                            }
                        }
                    }.makeAsyncIterator()
                }
                
                while let element = try await iterator?.next() {
                    return element
                }
                
                return nil
            }
        }
        
        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(upstream: upstream, keySelector: keySelector)
        }
    }
    
    public class KeyedAsyncSequence<Key: Hashable, Upstream: AsyncSequence>: AsyncSequence {
        public typealias Element = Upstream.Element
        var upstream: Upstream
        var elements: [Element]
        let key: Key

        init(upstream: Upstream, elements: [Element], key: Key) {
            self.upstream = upstream
            self.elements = elements
            self.key = key
        }
        
        public struct AsyncIterator: AsyncIteratorProtocol {
            
            var elements: [Element]
            var iterator: Array<Element>.Iterator?
            
            public mutating func next() async throws -> Element? {
                try Task.checkCancellation()
                return try await withCheckedThrowingContinuation { continuation in
                    if iterator == nil {
                        iterator = elements.makeIterator()
                    }
                    
                    return continuation.resume(returning: iterator?.next())
                }
            }
        }
        
        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(elements: elements)
        }
    }
}

extension AsyncSequence {
    public func groupBy<Key: Hashable>(keySelector: @escaping (Element) async -> Key) -> AsyncSequences.GroupBy<Self, Key> {
        AsyncSequences.GroupBy(upstream: self, keySelector: keySelector)
    }
}

extension AsyncSequences.GroupBy {
    class KeyedSequences {
        var sequences: [Key: Element] {
            get {
                lock.protect {
                    _sequences
                }
            }
            set {
                lock.protect {
                    _sequences = newValue
                }
            }
        }
        
        private var _sequences: [Key: Element]
        
        private let lock = NSRecursiveLock()
        
        init(sequences: [Key : Element] = [:]) {
            self._sequences = sequences
        }
    }
}
