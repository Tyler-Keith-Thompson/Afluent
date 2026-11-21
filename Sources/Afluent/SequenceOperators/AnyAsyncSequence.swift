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

    /// The iterator of an ``AnyAsyncSequence``, forwarding to the erased sequence's iterator.
    ///
    /// Like most iterators it is not `Sendable`: iterate it from one task at a time. Copies share the
    /// erased iterator's position.
    public struct AnyAsyncIterator<Element: Sendable>: AsyncIteratorProtocol {
        // A class box rather than an existential: `any AsyncIteratorProtocol<Element, Failure>`
        // needs macOS 15, and an unconstrained existential returns `Any`, which would need a cast
        // per element. Subclassing keeps the erased iterator's concrete type, so each `next()` is
        // one dynamic dispatch.
        private let box: IteratorBox<Element>

        init<I: AsyncIteratorProtocol>(erasing iterator: I) where I.Element == Element {
            box = ConcreteIteratorBox(iterator)
        }

        public mutating func next() async throws -> Element? {
            try await box.next()
        }
    }
}

@available(*, unavailable)
extension AsyncSequences.AnyAsyncIterator: Sendable {}

/// The erased iterator, as a class so ``AsyncSequences/AnyAsyncIterator`` can hold any concrete
/// iterator type behind one stored property.
private class IteratorBox<Element> {
    func next() async throws -> Element? {
        // Never called: every box is a ConcreteIteratorBox, which overrides it. A trap beats a
        // thrown error because reaching it is a bug in this file, not something a caller can handle.
        fatalError("IteratorBox.next() must be overridden")
    }
}

private final class ConcreteIteratorBox<Iterator: AsyncIteratorProtocol>: IteratorBox<Iterator.Element> {
    private var iterator: Iterator

    init(_ iterator: Iterator) {
        self.iterator = iterator
    }

    override func next() async throws -> Iterator.Element? {
        try await iterator.next()
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
