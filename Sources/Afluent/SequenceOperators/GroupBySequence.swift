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
                    iterator = AsyncThrowingStream<Element, Error> { continuation in
                        
                        let upstream = self.upstream
                        let keySelector = self.keySelector
                        let keyedSequences = self.keyedSequences
                        
                        Task {
                            for try await el in upstream {
                                let key = await keySelector(el)
                                if keyedSequences.sequences[key] != nil {
                                    keyedSequences.sequences[key]?.elements.append(el)
                                } else {
                                    let keyedAsyncSequence = KeyedAsyncSequence(upstream: upstream, elements: [el], key: key)
                                    keyedSequences.sequences[key] = keyedAsyncSequence
                                    continuation.yield(keyedAsyncSequence)
                                }
                            }
                            continuation.finish()
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
    
    public struct KeyedAsyncSequence<Key: Hashable, Upstream: AsyncSequence>: AsyncSequence {
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
                
                if iterator == nil {
                    iterator = elements.makeIterator()
                }
                
                return iterator?.next()
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