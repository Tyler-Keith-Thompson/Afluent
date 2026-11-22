//
//  AsyncIteratorSequence.swift
//  Afluent
//

extension AsyncSequences {
    /// A single-pass async sequence over an iterator you already made: the async counterpart of the standard
    /// library's `IteratorSequence`.
    ///
    /// Use it to subscribe to a subject before the code that consumes the subject runs. A ``PassthroughSubject``
    /// drops values sent while nobody is subscribed, and an operator such as `batch(strategy:)` subscribes only when
    /// its consumer's task starts iterating, so values sent in between are lost. Making the subject's iterator first
    /// subscribes at once; wrapping it in an `AsyncIteratorSequence` hands that subscription to any operator.
    ///
    /// ## Example
    /// ```swift
    /// let events = PassthroughSubject<String>()
    /// // Subscribes now: every value sent from here on is buffered for the batches below.
    /// let batches = AsyncIteratorSequence(events.makeAsyncIterator())
    ///     .batch(strategy: .count(2))
    /// events.send("launch")
    /// events.send("login")
    /// events.send(completion: .finished)
    ///
    /// let consumer = Task {
    ///     for try await batch in batches {
    ///         print(batch) // Prints: ["launch", "login"]
    ///     }
    /// }
    /// ```
    ///
    /// The subscription belongs to the wrapped iterator. A subject's iterator subscribes when it is made and buffers
    /// every value sent after that until it is read, without limit. It unsubscribes when the last copy of the
    /// iterator is released, whether or not it was ever iterated, and when a task waiting in its `next()` is
    /// cancelled; values sent after either are not delivered to it. To read the subject again, make a new iterator.
    ///
    /// The sequence is single-pass. Each `makeAsyncIterator()` returns a copy of the wrapped iterator, so a
    /// value-type iterator starts over from where it was wrapped, and a reference-type one, such as a subject's,
    /// shares its elements among every iteration.
    public struct AsyncIteratorSequence<Base: AsyncIteratorProtocol>: AsyncSequence {
        public typealias Element = Base.Element

        let base: Base

        /// Creates a sequence over `base`.
        ///
        /// - Parameter base: The iterator whose elements the sequence yields.
        public init(_ base: Base) {
            self.base = base
        }

        public struct AsyncIterator: AsyncIteratorProtocol {
            var base: Base

            public mutating func next() async throws -> Base.Element? {
                try await base.next()
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(base: base)
        }
    }
}

extension AsyncSequences.AsyncIteratorSequence: Sendable where Base: Sendable {}
extension AsyncSequences.AsyncIteratorSequence.AsyncIterator: Sendable where Base: Sendable {}

public typealias AsyncIteratorSequence = AsyncSequences.AsyncIteratorSequence
