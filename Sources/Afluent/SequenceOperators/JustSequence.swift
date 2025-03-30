////
////  JustSequence.swift
////
////
////  Created by Tyler Thompson on 12/24/23.
////
//
//import Foundation
//
//extension AsyncSequences {
//    /// An `AsyncSequence` that emits a single specified element and then completes.
//    ///
//    /// `Just` is a simple `AsyncSequence` that emits only one element and then finishes. It's useful for creating sequences with a single, known value, often for testing or combining with other asynchronous sequences.
//    ///
//    /// - Parameter value: The single element that this sequence will emit.
//    public struct Just<Element: Sendable>: AsyncSequence, Sendable {
//        let val: Element
//
//        /// Creates a `Just` sequence with the specified element.
//        ///
//        /// - Parameter value: The single element to emit.
//        public init(_ value: Element) {
//            val = value
//        }
//
//        public struct AsyncIterator: AsyncIteratorProtocol {
//            let val: Element
//            var executed = false
//
//            public mutating func next() async throws -> Element? {
//                if !executed {
//                    executed = true
//                    return val
//                } else {
//                    return nil
//                }
//            }
//        }
//
//        public func makeAsyncIterator() -> AsyncIterator {
//            AsyncIterator(val: val)
//        }
//    }
//}
//
//public typealias Just = AsyncSequences.Just
