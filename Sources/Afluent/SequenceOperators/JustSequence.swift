//
//  JustSequence.swift
//
//
//  Created by Tyler Thompson on 12/24/23.
//

import Foundation

extension AsyncSequences {
    /// An async sequence that emits a single specified element and then completes.
    ///
    /// Use `Just` to create a sequence that yields one value and then finishes, often for testing, composition, or as a source of a single known value.
    ///
    /// ## Example
    /// ```swift
    /// for await value in Just(1) {
    ///     print(value) // Prints: 1
    /// }
    /// ```
    ///
    /// - Note: If you want to emit a single asynchronous value (not a sequence), consider using `DeferredTask` instead.
    public struct Just<Element: Sendable>: AsyncSequence, Sendable {
        let val: Element

        /// Creates a `Just` sequence with the specified element.
        ///
        /// - Parameter value: The single element to emit.
        public init(_ value: Element) {
            val = value
        }

        public struct AsyncIterator: AsyncIteratorProtocol {
            let val: Element
            var executed = false

            public mutating func next() async throws -> Element? {
                if !executed {
                    executed = true
                    return val
                } else {
                    return nil
                }
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(val: val)
        }
    }
}

public typealias Just = AsyncSequences.Just

