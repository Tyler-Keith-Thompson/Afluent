//
//  FailSequence.swift
//  Afluent
//

import Foundation

extension AsyncSequences {
    /// An async sequence that emits no elements and finishes at once with the specified error.
    ///
    /// Use `Fail` where a sequence is expected but the answer is already known to be an error: a
    /// branch of `flatMap` that rejects its input, a stand-in for a failing source in tests, or the
    /// error case of a sequence built from a `Result`.
    ///
    /// The first call to `next()` throws the error, even if the task is cancelled; every call after
    /// that returns `nil`.
    ///
    /// ## Example
    /// ```swift
    /// struct InvalidQuery: Error {}
    ///
    /// let results = queries.flatMap { query -> AnyAsyncSequence<User> in
    ///     guard !query.isEmpty else {
    ///         return Fail(outputType: User.self, error: InvalidQuery()).eraseToAnyAsyncSequence()
    ///     }
    ///     return search(query).eraseToAnyAsyncSequence()
    /// }
    /// ```
    public struct Fail<Element: Sendable>: AsyncSequence, Sendable {
        let error: any Error

        /// Creates a sequence that finishes with `error`, for an element type the context names.
        ///
        /// - Parameter error: The error the sequence throws in place of any element.
        public init(error: any Error) {
            self.error = error
        }

        /// Creates a sequence of `Element` that finishes with `error`, naming the element type where
        /// the context doesn't.
        ///
        /// - Parameters:
        ///   - outputType: The type of element the sequence would have emitted.
        ///   - error: The error the sequence throws in place of any element.
        public init(outputType: Element.Type, error: any Error) {
            self.error = error
        }

        public struct AsyncIterator: AsyncIteratorProtocol {
            let error: any Error
            var finished = false

            public mutating func next() async throws -> Element? {
                guard !finished else { return nil }
                finished = true
                throw error
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(error: error)
        }
    }
}

public typealias Fail = AsyncSequences.Fail
