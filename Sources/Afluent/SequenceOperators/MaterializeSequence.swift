//
//  MaterializeSequence.swift
//
//
//  Created by Tyler Thompson on 12/1/23.
//

import Foundation

extension AsyncSequences {
    /// Represents an event (element, error, or completion) from a materialized async sequence.
    public enum Event<Element: Sendable>: Sendable {
        /// An element from the upstream sequence.
        case element(Element)
        /// An error encountered in the upstream sequence.
        case failure(Error)
        /// The completion of the upstream sequence.
        case complete
    }

    /// Used as the implementation detail for the ``AsyncSequence/materialize()`` operator.
    public struct Materialize<Upstream: AsyncSequence & Sendable>: AsyncSequence, Sendable
    where Upstream.Element: Sendable {
        public typealias Element = Event<Upstream.Element>

        let upstream: Upstream

        public struct AsyncIterator: AsyncIteratorProtocol {
            var upstream: Upstream.AsyncIterator
            var completed = false

            public mutating func next() async throws -> Element? {
                guard !completed else { return nil }
                do {
                    try Task.checkCancellation()
                    if let val = try await upstream.next() {
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
            AsyncIterator(upstream: upstream.makeAsyncIterator())
        }
    }
}

extension AsyncSequence where Self: Sendable {
    /// Transforms all elements, errors, and completion of the sequence into `Event` values.
    ///
    /// Use this to handle elements, errors, and completion uniformly as events.
    ///
    /// ## Example
    /// ```
    /// for await event in Just(1).materialize() {
    ///     switch event {
    ///     case .element(let value): print("Element: \(value)")
    ///     case .failure(let error): print("Failure: \(error)")
    ///     case .complete: print("Complete")
    ///     }
    /// }
    /// ```
    public func materialize() -> AsyncSequences.Materialize<Self> where Element: Sendable {
        AsyncSequences.Materialize(upstream: self)
    }
}

