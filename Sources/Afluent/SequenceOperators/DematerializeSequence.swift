//
//  DematerializeSequence.swift
//
//
//  Created by Tyler Thompson on 12/1/23.
//

import Foundation

extension AsyncSequences {
    public struct Dematerialize<Upstream: AsyncSequence & Sendable, Element: Sendable>: AsyncSequence, Sendable where Upstream.Element == AsyncSequences.Event<Element> {
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
    /// Transforms a sequence of `Event` values back into their original form in an `AsyncSequence`.
    ///
    /// This method is the inverse of `materialize`. It takes an `AsyncSequence` of `Event` values and transforms it back into an `AsyncSequence` of the original elements, propagating errors as thrown exceptions.
    ///
    /// - Note: The sequence must be of type `AsyncSequences.Event<T>`. The `dematerialize` method will extract the original elements and errors from these events.
    ///
    /// - Returns: An `AsyncSequences.Dematerialize` instance that represents the original `AsyncSequence` with its elements and errors.
    /// - Throws: Re-throws any errors that were encapsulated in the `Event.failure` cases.
    public func dematerialize<T>() -> AsyncSequences.Dematerialize<Self, T> where Element == AsyncSequences.Event<T> {
        AsyncSequences.Dematerialize(upstream: self)
    }
}
