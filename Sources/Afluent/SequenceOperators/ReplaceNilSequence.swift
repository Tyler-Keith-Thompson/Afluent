////
////  ReplaceNilSequence.swift
////
////
////  Created by Tyler Thompson on 12/17/23.
////
//
//import Foundation
//
//extension AsyncSequences {
//    public struct ReplaceNil<Upstream: AsyncSequence & Sendable, Output: Sendable>: AsyncSequence,
//        Sendable
//    where Upstream.Element == Output? {
//        public typealias Element = Upstream.Element
//        let upstream: Upstream
//        let newOutput: Output
//
//        public struct AsyncIterator: AsyncIteratorProtocol {
//            var upstreamIterator: Upstream.AsyncIterator
//            let newOutput: Output
//
//            public mutating func next() async throws -> Element? {
//                try Task.checkCancellation()
//                switch try await upstreamIterator.next() {
//                    case .none: return nil
//                    case .some(.none): return newOutput
//                    case .some(.some(let output)): return output
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
//    /// Replaces any `nil` values from the upstream `AsyncSequence` with the provided non-nil value.
//    ///
//    /// - Parameter value: The value to emit when the upstream emits `nil`.
//    ///
//    /// - Returns: An `AsyncSequence` that emits the specified value instead of `nil` when the upstream emits `nil`.
//    public func replaceNil<E>(with value: E) -> AsyncSequences.ReplaceNil<Self, E>
//    where Element == E? {
//        AsyncSequences.ReplaceNil(upstream: self, newOutput: value)
//    }
//}
