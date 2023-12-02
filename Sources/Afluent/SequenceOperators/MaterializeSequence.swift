//
//  MaterializeSequence.swift
//
//
//  Created by Tyler Thompson on 12/1/23.
//

import Foundation

extension AsyncSequences {
    /// Represents the different kinds of events that can be emitted by `Materialize`.
    public enum Event<Element> {
        /// An element from the upstream sequence.
        case element(Element)
        /// An error encountered in the upstream sequence.
        case failure(Error)
        /// The completion of the upstream sequence.
        case complete
    }
    
    public struct Materialize<Upstream: AsyncSequence>: AsyncSequence {
        public typealias Element = Event<Upstream.Element>
        
        let upstream: Upstream
        
        public struct AsyncIterator: AsyncIteratorProtocol {
            let upstream: Upstream
            var completed = false
            lazy var iterator = upstream.makeAsyncIterator()
            
            public mutating func next() async throws -> Element? {
                guard !completed else { return nil }
                do {
                    try Task.checkCancellation()
                    if let val = try await iterator.next() {
                        return .element(val)
                    } else {
                        completed = true
                        return .complete
                    }
                } catch {
                    guard !(error is CancellationError) else { throw error }
                    return .failure(error)
                }
            }
        }
        
        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(upstream: upstream)
        }
    }
}

extension AsyncSequence {
    /// Transforms the elements, completion, and errors of the current `AsyncSequence` into `Event` values.
    ///
    /// This method wraps the `AsyncSequence` and emits each of its elements, errors, and completion as distinct `Event` cases. It's useful for uniformly handling all aspects of the sequence's lifecycle.
    ///
    /// - Returns: An `AsyncSequences.Materialize` instance that represents the transformed sequence.
    public func materialize() -> AsyncSequences.Materialize<Self> {
        AsyncSequences.Materialize(upstream: self)
    }
}
