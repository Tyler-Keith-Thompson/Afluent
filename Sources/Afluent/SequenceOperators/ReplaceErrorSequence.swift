////
////  ReplaceErrorSequence.swift
////
////
////  Created by Tyler Thompson on 12/17/23.
////
//
//import Foundation
//
//extension AsyncSequences {
//    public struct ReplaceError<Upstream: AsyncSequence & Sendable, Output: Sendable>: AsyncSequence,
//        Sendable
//    where Upstream.Element == Output {
//        public typealias Element = Upstream.Element
//        let upstream: Upstream
//        let newOutput: Output
//
//        public struct AsyncIterator: AsyncIteratorProtocol {
//            var upstreamIterator: Upstream.AsyncIterator
//            let newOutput: Output
//
//            public mutating func next() async throws -> Element? {
//                do {
//                    try Task.checkCancellation()
//                    return try await upstreamIterator.next()
//                } catch {
//                    guard !(error is CancellationError) else { throw error }
//                    return newOutput
//                }
//            }
//        }
//
//        public func makeAsyncIterator() -> AsyncIterator {
//            AsyncIterator(
//                upstreamIterator: upstream.makeAsyncIterator(),
//                newOutput: newOutput)
//        }
//    }
//}
//
//extension AsyncSequence where Self: Sendable {
//    /// Replaces any errors from the upstream `AsyncSequence` with the provided value.
//    ///
//    /// - Parameter value: The value to emit upon encountering an error.
//    ///
//    /// - Returns: An `AsyncSequence` that emits the specified value instead of failing when the upstream fails.
//    public func replaceError(with value: Element) -> AsyncSequences.ReplaceError<Self, Element>
//    where Element: Sendable {
//        AsyncSequences.ReplaceError(upstream: self, newOutput: value)
//    }
//}
