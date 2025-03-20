//
//  OutputSequence.swift
//  Afluent
//
//  Created by Roman Temchenko on 2025-03-05.
//

import Foundation

extension AsyncSequences {
    public struct OutputAt<Upstream: AsyncSequence & Sendable>: AsyncSequence, Sendable {
        public typealias Element = Upstream.Element
        let upstream: Upstream
        let index: Int

        public struct AsyncIterator: AsyncIteratorProtocol {
            var upstreamIterator: Upstream.AsyncIterator
            let index: Int
            var nextIndex = 0

            public mutating func next() async throws -> Element? {
                guard nextIndex <= index else { return nil }
                while let next = try await upstreamIterator.next() {
                    if nextIndex == index {
                        nextIndex &+= 1
                        return next
                    }
                    nextIndex &+= 1
                }
                return nil
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(upstreamIterator: upstream.makeAsyncIterator(), index: index)
        }
    }
    
    public struct OutputIn<Upstream: AsyncSequence & Sendable>: AsyncSequence, Sendable {
        public typealias Element = Upstream.Element
        
        let upstream: Upstream
        let range: Range<Int>

        public struct AsyncIterator: AsyncIteratorProtocol {
            var upstreamIterator: Upstream.AsyncIterator
            let range: Range<Int>
            var nextIndex = 0

            public mutating func next() async throws -> Element? {
                guard nextIndex < range.upperBound else { return nil }
                while let next = try await upstreamIterator.next() {
                    if range.contains(nextIndex) {
                        nextIndex &+= 1
                        return next
                    }
                    nextIndex &+= 1
                }
                return nil
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(upstreamIterator: upstream.makeAsyncIterator(), range: range)
        }
    }
    
}

extension AsyncSequence where Self: Sendable {
    
    /// Returns a sequence containing a specific indexed element.
    /// If the sequence finishes normally or with an error before emitting the specified element, then the sequence doesn’t produce any elements.
    /// - Parameter index: The index that indicates the element needed.
    /// - Returns: A sequence containing a specific indexed element.
    public func output(at index: Int) -> AsyncSequences.OutputAt<Self> {
        AsyncSequences.OutputAt(upstream: self, index: index)
    }
    
    /// Returns an async sequence that contains, in order, the elements of the base sequence specified by the range.
    ///
    /// ### Discussion:
    /// Optimized to be used with built-in range types. Completes normally after returning all elements.
    /// 
    /// ### Example:
    /// ```swift
    ///  let originalSequence = [0, 3, 5, 7, 9].async
    ///  for try await element in originalSequence.output(in: 1..<4) {
    ///      print("\(element)")
    ///  }
    ///  // Prints 3, 5, 7
    /// ```
    ///
    /// - Parameter range: A range that indicates which elements to include.
    /// - Returns: An async sequence that contains, in order, the elements of the base sequence specified by the range.
    public func output<R>(in range: R) -> AsyncSequences.OutputIn<Self> where R : RangeExpression, R.Bound == Int, R: Sendable {
        AsyncSequences.OutputIn(upstream: self,
                                range: range.relative(to: 0..<Int.max))
    }
}
