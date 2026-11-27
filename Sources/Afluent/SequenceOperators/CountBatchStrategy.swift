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
    /// A `count` below 1 is accepted here, and the batched sequence throws ``NonPositiveCount``
    /// from its first `next()`.
    ///
    /// - Parameter count: The number of elements per batch: at least 1.
    public init(_ count: Int) {
        self.count = count
    }

    public func flushes(pending: [Element]) -> Bool {
        pending.count >= count
    }

    /// The error a batched sequence throws when its ``CountBatchStrategy`` has a count below 1.
    public struct NonPositiveCount: Error, Equatable {
        /// Creates the error.
        public init() {}
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
extension CountBatchStrategy: ValidatedBatchStrategy {
    func validate() throws {
        guard count >= 1 else { throw NonPositiveCount() }
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
    /// - Parameter count: The number of elements per batch: at least 1, or the batched sequence
    ///   throws ``CountBatchStrategy/NonPositiveCount`` from its first `next()`.
    /// - Returns: A ``CountBatchStrategy``.
    public static func count<Batched>(_ count: Int) -> CountBatchStrategy<Batched>
    where Self == CountBatchStrategy<Batched> {
        CountBatchStrategy(count)
    }
}
