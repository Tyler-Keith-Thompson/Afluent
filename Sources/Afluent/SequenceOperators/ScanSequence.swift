//
//  ScanSequence.swift
//  Afluent
//
//  Created by Tyler Thompson on 6/14/25.
//

import Foundation

extension AsyncSequences {
    public struct Scan<Upstream: AsyncSequence & Sendable, Output: Sendable>: AsyncSequence, Sendable
    where Upstream.Element: Sendable {
        public typealias Element = Output

        let upstream: Upstream
        let initialResult: Output
        let nextPartialResult: @Sendable (Output, Upstream.Element) async throws -> Output

        public struct AsyncIterator: AsyncIteratorProtocol {
            var upstream: Upstream.AsyncIterator
            let nextPartialResult: @Sendable (Output, Upstream.Element) async throws -> Output
            private var nextResult: Output

            init(upstream: Upstream.AsyncIterator, initialResult: Output, nextPartialResult: @Sendable @escaping (Output, Upstream.Element) async throws -> Output) {
                self.upstream = upstream
                self.nextResult = initialResult
                self.nextPartialResult = nextPartialResult
            }
            
            public mutating func next() async throws -> Element? {
                try Task.checkCancellation()
                guard let upstreamNext = try await upstream.next() else { return nil }
                nextResult = try await nextPartialResult(nextResult, upstreamNext)
                return nextResult
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(upstream: upstream.makeAsyncIterator(), initialResult: initialResult, nextPartialResult: nextPartialResult)
        }
    }
}

extension AsyncSequence where Self: Sendable {
    /// Transforms elements from the upstream sequence by providing the current
    /// element to a closure along with the last value returned by the closure.
    ///
    /// Use ``AsyncSequence/scan(_:_:)`` to accumulate all previously-published values into a single
    /// value, which you then combine with each newly-published value.
    ///
    /// - Parameters:
    ///   - initialResult: The previous result returned by the `nextPartialResult` closure.
    ///   - nextPartialResult: A closure that takes as its arguments the previous value returned by the closure and the next element emitted from the upstream sequence.
    /// - Returns: A sequence that transforms elements by applying a closure that receives its previous return value and the next element from the upstream sequence.
    public func scan<T>(_ initialResult: T, _ nextPartialResult: @Sendable @escaping (T, Self.Element) async throws -> T) -> AsyncSequences.Scan<Self, T> {
        .init(upstream: self, initialResult: initialResult, nextPartialResult: nextPartialResult)
    }
}
