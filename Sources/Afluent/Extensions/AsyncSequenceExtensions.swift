//
//  AsyncSequenceExtensions.swift
//
//
//  Created by Tyler Thompson on 12/1/23.
//

import Foundation

extension AsyncSequence where Element: Sendable {
    /// Returns the first element of the sequence, or `nil` if the sequence is empty.
    ///
    /// This method is a convenience overload for async sequences, returning the first element encountered, or `nil` if none is produced.
    ///
    /// If the sequence throws before yielding a value, the error is rethrown.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let stream = AsyncStream<Int> { continuation in
    ///     continuation.yield(42)
    ///     continuation.yield(100)
    ///     continuation.finish()
    /// }
    ///
    /// if let first = try await stream.first() {
    ///     print("First: \(first)") // Prints: First: 42
    /// }
    /// ```
    @_disfavoredOverload public func first() async rethrows -> Self.Element? {
        try await first { _ in true }
    }
}
