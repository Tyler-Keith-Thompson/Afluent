//
//  AnyAsyncSequence.swift
//
//
//  Created by Tyler Thompson on 11/28/23.
//

import Foundation

public typealias AnyAsyncSequence = AsyncSequences.AnyAsyncSequence
extension AsyncSequences {
    public struct AnyAsyncSequence<Element: Sendable>: AsyncSequence, Sendable {
        let makeIterator: @Sendable () -> AnyAsyncIterator<Element>

        public init<S: AsyncSequence & Sendable>(erasing sequence: S) where S.Element == Element, S.AsyncIterator: Sendable, S.Element: Sendable {
            makeIterator = { AnyAsyncIterator(erasing: sequence.makeAsyncIterator()) }
        }

        public func makeAsyncIterator() -> AnyAsyncIterator<Element> {
            makeIterator()
        }
    }

    public struct AnyAsyncIterator<Element: Sendable>: AsyncIteratorProtocol, Sendable {
        private var iterator: any (AsyncIteratorProtocol & Sendable)

        init<I: AsyncIteratorProtocol & Sendable>(erasing iterator: I) where I.Element == Element {
            self.iterator = iterator
        }

        public mutating func next() async throws -> Element? {
            // Eventually, we'll have primary associated types making the casting nonsense below unnecessary
            // https://github.com/apple/swift-evolution/blob/main/proposals/0358-primary-associated-types-in-stdlib.md#alternatives-considered

            return try await iterator.next() as? Element
        }
    }
}

extension AsyncSequence where Self: Sendable, Element: Sendable, Self.AsyncIterator: Sendable {
    /// Type erases the current sequence, useful when you need a concrete type that's easy to predict.
    public func eraseToAnyAsyncSequence() -> AsyncSequences.AnyAsyncSequence<Element> {
        AsyncSequences.AnyAsyncSequence(erasing: self)
    }
}
