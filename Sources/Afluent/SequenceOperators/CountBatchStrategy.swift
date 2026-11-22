//
//  CountBatchStrategy.swift
//  Afluent
//

import Foundation

/// A ``BatchStrategy`` that flushes whenever a given number of elements is pending.
///
/// Every flush empties the batch, so after a flush another strategy in ``EitherBatchStrategy``
/// caused, the count starts again from zero.
///
/// ## Example
/// ```swift
/// for try await pair in [1, 2, 3, 4, 5].async.batch(strategy: .count(2)) {
///     print(pair) // Prints [1, 2], then [3, 4], then [5]
/// }
/// ```
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
public struct CountBatchStrategy<Element>: BatchStrategy {
    /// The number of elements in every batch but the last, which holds what is pending when the
    /// upstream finishes.
    public let count: Int

    /// Creates a strategy that flushes every `count` elements.
    ///
    /// - Parameter count: The number of elements per batch.
    /// - Precondition: `count` is at least 1.
    public init(_ count: Int) {
        precondition(count >= 1, "A batch's count must be at least 1, not \(count)")
        self.count = count
    }

    public func flushes(pending: [Element]) -> Bool {
        pending.count >= count
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
extension BatchStrategy {
    /// Flushes whenever the given number of elements is pending.
    ///
    /// ## Example
    /// ```swift
    /// for try await pair in [1, 2, 3, 4, 5].async.batch(strategy: .count(2)) {
    ///     print(pair) // Prints [1, 2], then [3, 4], then [5]
    /// }
    /// ```
    ///
    /// - Parameter count: The number of elements per batch.
    /// - Returns: A ``CountBatchStrategy``.
    /// - Precondition: `count` is at least 1.
    public static func count<Batched>(_ count: Int) -> CountBatchStrategy<Batched>
    where Self == CountBatchStrategy<Batched> {
        CountBatchStrategy(count)
    }
}
