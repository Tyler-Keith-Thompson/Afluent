////
////  MapErrorSequence.swift
////
////
////  Created by Tyler Thompson on 12/17/23.
////
//
//import Foundation
//
//extension AsyncSequences {
//    public struct MapError<Upstream: AsyncSequence & Sendable>: AsyncSequence, Sendable {
//        public typealias Element = Upstream.Element
//        let upstream: Upstream
//        let transform: @Sendable (Error) -> Error
//
//        public struct AsyncIterator: AsyncIteratorProtocol {
//            var upstreamIterator: Upstream.AsyncIterator
//            let transform: (Error) -> Error
//
//            public mutating func next() async throws -> Element? {
//                do {
//                    try Task.checkCancellation()
//                    return try await upstreamIterator.next()
//                } catch {
//                    throw transform(error)
//                }
//            }
//        }
//
//        public func makeAsyncIterator() -> AsyncIterator {
//            AsyncIterator(
//                upstreamIterator: upstream.makeAsyncIterator(),
//                transform: transform)
//        }
//    }
//}
//
//extension AsyncSequence where Self: Sendable {
//    /// Transforms the error produced by the `AsyncSequence`.
//    ///
//    /// This function allows you to modify or replace the error produced by the current sequence. It's useful for converting between error types or adding additional context to errors.
//    ///
//    /// - Parameter transform: A closure that takes the original error and returns a transformed error.
//    ///
//    /// - Returns: An `AsyncSequence` that produces the transformed error.
//    public func mapError(_ transform: @Sendable @escaping (Error) -> Error)
//        -> AsyncSequences.MapError<Self>
//    {
//        AsyncSequences.MapError(upstream: self, transform: transform)
//    }
//
//    /// Transforms the error produced by the `AsyncSequence`.
//    ///
//    /// This function allows you to modify or replace the error produced by the current sequence. It's useful for converting between error types or adding additional context to errors.
//    ///
//    /// - Parameters:
//    ///   - error: The specific error to be transformed. This error is equatable, allowing for precise matching.
//    ///   - transform: A closure that takes the matched error and returns a transformed error.
//    ///
//    /// - Returns: An `AsyncSequence` that produces the transformed error.
//    public func mapError<E: Error & Equatable>(
//        _ error: E, _ transform: @Sendable @escaping (Error) -> Error
//    ) -> AsyncSequences.MapError<Self> {
//        mapError {
//            if let e = $0 as? E, e == error { return transform(e) }
//            return $0
//        }
//    }
//}
