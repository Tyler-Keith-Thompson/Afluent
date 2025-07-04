//
//  DematerializeSequence.swift
//
//
//  Created by Tyler Thompson on 12/1/23.
//

import Foundation

extension AsyncSequences {
    /// Used as the implementation detail for the ``AsyncSequence/dematerialize()`` operator.
    public struct Dematerialize<Upstream: AsyncSequence & Sendable, Element: Sendable>:
        AsyncSequence, Sendable
    where Upstream.Element == AsyncSequences.Event<Element> {
        let upstream: Upstream

        public struct AsyncIterator: AsyncIteratorProtocol {
            var upstream: Upstream.AsyncIterator

            public mutating func next() async throws -> Element? {
                try Task.checkCancellation()
                if let val = try await upstream.next() {
                    switch val {
                        case .element(let element): return element
                        case .failure(let error): throw error
                        case .complete: return nil
                    }
                } else {
                    return nil
                }
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(upstream: upstream.makeAsyncIterator())
        }
    }
}

extension AsyncSequence where Self: Sendable {
    /// Transforms a sequence of `Event` values back into a sequence of their original elements, rethrowing errors.
    ///
    /// This is the inverse of `materialize()`. Use it to recover values and errors from a sequence of events.
    ///
    /// ## Example
    /// ```swift
    /// for try await value in Just(1).materialize().dematerialize() {
    ///     print(value) // Prints: 1
    /// }
    /// ```
    public func dematerialize<T>() -> AsyncSequences.Dematerialize<Self, T>
    where Element == AsyncSequences.Event<T> {
        AsyncSequences.Dematerialize(upstream: self)
    }
}
