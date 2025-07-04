//
//  FlatMapSequence.swift
//
//
//  Created by Tyler Thompson on 3/16/24.
//

import Atomics
import Foundation

extension AsyncSequences {
    /// Used as the implementation detail for the ``AsyncSequence/flatMap(maxSubscriptions:_:)`` operator.
    public struct FlatMap<
        Upstream: AsyncSequence & Sendable, SegmentOfResult: AsyncSequence & Sendable
    >: AsyncSequence, Sendable where Upstream.Element: Sendable, SegmentOfResult.Element: Sendable {
        public typealias Element = SegmentOfResult.Element
        let upstream: Upstream
        let maxSubscriptons: SubscriptionDemand
        let transform: @Sendable (Upstream.Element) async throws -> SegmentOfResult

        public struct AsyncIterator: AsyncIteratorProtocol {
            var upstream: Upstream
            let maxSubscriptons: SubscriptionDemand
            let transform: @Sendable (Upstream.Element) async throws -> SegmentOfResult
            var iterator: AsyncThrowingStream<Element, Error>.Iterator?

            public mutating func next() async throws -> SegmentOfResult.Element? {
                try Task.checkCancellation()
                switch maxSubscriptons {
                    case .unlimited:
                        if iterator == nil {
                            iterator = AsyncThrowingStream<Element, Error> {
                                [upstream, transform] continuation in
                                Task { [transform] in
                                    do {
                                        try Task.checkCancellation()
                                        try await withThrowingTaskGroup(of: Void.self) { group in
                                            for try await el in upstream {
                                                group.addTask {
                                                    try Task.checkCancellation()
                                                    for try await e in try await transform(el) {
                                                        continuation.yield(e)
                                                    }
                                                }
                                            }
                                        }

                                        continuation.finish()
                                    } catch {
                                        continuation.finish(throwing: error)
                                    }
                                }
                            }.makeAsyncIterator()
                        }

                        while let element = try await iterator?.next() {
                            return element
                        }

                        return nil
                }
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(
                upstream: upstream, maxSubscriptons: maxSubscriptons, transform: transform)
        }
    }
}

extension AsyncSequence {
    /// Merges the results of mapping each element to an `AsyncSequence`, with control over subscription demand.
    ///
    /// Unlike the standard library's `flatMap`, this operator allows you to control how many inner sequences may be subscribed to concurrently.
    ///
    /// - Parameters:
    ///   - maxSubscriptions: The maximum number of concurrent inner subscriptions. Use `.unlimited` for no limit.
    ///   - transform: Transforms each element into an `AsyncSequence`.
    ///
    /// ## Example
    /// ```swift
    /// for try await value in Just(1).flatMap(maxSubscriptions: .unlimited) { i in Just(i * 2) } {
    ///     print(value) // Prints: 2
    /// }
    /// ```
    public func flatMap<SegmentOfResult: AsyncSequence>(
        maxSubscriptions: SubscriptionDemand,
        _ transform: @Sendable @escaping (Self.Element) async throws -> SegmentOfResult
    ) -> AsyncSequences.FlatMap<Self, SegmentOfResult> {
        AsyncSequences.FlatMap(
            upstream: self, maxSubscriptons: maxSubscriptions, transform: transform)
    }
}

/// Specifies the number of concurrent inner subscriptions for operators like ``AsyncSequence/flatMap(maxSubscriptions:_:)``.
///
/// Use `.unlimited` to allow unlimited concurrency.
public enum SubscriptionDemand: Sendable {
    /// Allows unlimited concurrent inner subscriptions.
    case unlimited
}
