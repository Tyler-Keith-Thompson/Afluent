//
//  AnyAsyncSequence.swift
//
//
//  Created by Tyler Thompson on 11/28/23.
//

import Foundation

/// A type-erased async sequence.
///
/// Used as the backing implementation for ``_Concurrency/AsyncSequence/eraseToAnyAsyncSequence()``
public typealias AnyAsyncSequence = AsyncSequences.AnyAsyncSequence
extension AsyncSequences {
    /// A type-erased async sequence.
    ///
    /// Used as the backing implementation for ``_Concurrency/AsyncSequence/eraseToAnyAsyncSequence()``
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
            // The iterator is stored as `any AsyncIteratorProtocol` because its `Failure` may be `Never`,
            // which `any AsyncIteratorProtocol<Element, any Error>` cannot hold. Unwrap before casting:
            // when `Element` is itself Optional, the end-of-sequence `nil` casts to `.some(nil)`.
            guard let element = try await state.iterator.next() else { return nil }
            return element as? Element
        }
    }
}

extension AsyncSequence where Self: Sendable, Element: Sendable {
    /// Returns a type-erased async sequence.
    ///
    /// Use this to hide the underlying concrete type of an async sequence when you need to pass it generically.
    ///
    /// ## Example
    /// ```swift
    /// let stream = AsyncStream<Int> { continuation in
    ///     continuation.yield(1)
    ///     continuation.yield(2)
    ///     continuation.finish()
    /// }
    /// let erased = stream.eraseToAnyAsyncSequence()
    /// for await value in erased {
    ///     print(value)
    /// }
    /// ```
    public func eraseToAnyAsyncSequence() -> AsyncSequences.AnyAsyncSequence<Element> {
        AsyncSequences.AnyAsyncSequence(erasing: self)
    }
}
