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
public struct CountBatchStrategy: BatchStrategy {
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

    public func flushes<Element>(pending: [Element]) -> Bool {
        pending.count >= count
    }
}

extension BatchStrategy where Self == CountBatchStrategy {
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
    public static func count(_ count: Int) -> CountBatchStrategy {
        CountBatchStrategy(count)
    }
}
