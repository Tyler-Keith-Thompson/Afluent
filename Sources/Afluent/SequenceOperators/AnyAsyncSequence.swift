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

        public init<S: AsyncSequence & Sendable>(erasing sequence: S)
        where S.Element == Element, S.Element: Sendable {
            makeIterator = { AnyAsyncIterator(erasing: sequence.makeAsyncIterator()) }
        }

        public func makeAsyncIterator() -> AnyAsyncIterator<Element> {
            makeIterator()
        }
    }

    public struct AnyAsyncIterator<Element: Sendable>: AsyncIteratorProtocol, Sendable {
        private final class State: @unchecked Sendable {
            private var lock = NSRecursiveLock()
            private var _iterator: any AsyncIteratorProtocol
            var iterator: any AsyncIteratorProtocol {
                get {
                    lock.lock()
                    defer { lock.unlock() }
                    return _iterator
                }
                set {
                    lock.lock()
                    defer { lock.unlock() }
                    _iterator = newValue
                }
            }

            init(iterator: any AsyncIteratorProtocol) {
                _iterator = iterator
            }
        }

        private let state: State
        init<I: AsyncIteratorProtocol>(erasing iterator: I) where I.Element == Element {
            state = State(iterator: iterator)
        }

        public mutating func next() async throws -> Element? {
            // Eventually, we'll have primary associated types making the casting nonsense below unnecessary
            // https://github.com/apple/swift-evolution/blob/main/proposals/0358-primary-associated-types-in-stdlib.md#alternatives-considered

            return try await state.iterator.next() as? Element
        }
    }
}

extension AsyncSequence where Self: Sendable, Element: Sendable {
    /// Type erases the current sequence, useful when you need a concrete type that's easy to predict.
    public func eraseToAnyAsyncSequence() -> AsyncSequences.AnyAsyncSequence<Element> {
        AsyncSequences.AnyAsyncSequence(erasing: self)
    }
}
