//
//  FlatMapSequence.swift
//
//
//  Created by Tyler Thompson on 3/16/24.
//

import Atomics
import Foundation

extension AsyncSequences {
    public struct FlatMap<Upstream: AsyncSequence & Sendable, SegmentOfResult: AsyncSequence & Sendable>: AsyncSequence where Upstream.Element: Sendable {
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
                            iterator = AsyncThrowingStream<Element, Error> { [upstream, transform] continuation in
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
            AsyncIterator(upstream: upstream, maxSubscriptons: maxSubscriptons, transform: transform)
        }
    }
}

extension AsyncSequence {
    public func flatMap<SegmentOfResult: AsyncSequence>(maxSubscriptions: SubscriptionDemand, _ transform: @escaping @Sendable (Self.Element) async throws -> SegmentOfResult) -> AsyncSequences.FlatMap<Self, SegmentOfResult> {
        AsyncSequences.FlatMap(upstream: self, maxSubscriptons: maxSubscriptions, transform: transform)
    }
}

public enum SubscriptionDemand {
    case unlimited
}
