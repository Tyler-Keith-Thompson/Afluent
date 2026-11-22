//
//  EitherBatchStrategy.swift
//  Afluent
//

import Foundation

/// A ``BatchStrategy`` that flushes when any of several strategies does.
///
/// Every flush starts all of them over, whichever one caused it. With no strategies, the batched
/// sequence emits everything in one array when the upstream finishes. A strategy among them that
/// throws ends the batched sequence with its error.
///
/// ## Example
/// ```swift
/// let flush = PassthroughSubject<Void>()
/// let strategy = EitherBatchStrategy(
///     .count(10),
///     .time(interval: .milliseconds(500), clock: ContinuousClock()),
///     .signal(flush))
/// for try await batch in events.batch(strategy: strategy) {
///     send(batch) // At most 10 events, at most half a second old
/// }
/// ```
public struct EitherBatchStrategy: BatchStrategy {
    // `any` rather than a variadic generic type (`EitherBatchStrategy<each S>`): those need the
    // macOS 14 / iOS 17 runtime, and Afluent supports macOS 13 / iOS 15.
    /// The strategies, any of which flushes.
    public let strategies: [any BatchStrategy]

    /// Creates a strategy that flushes when any of `strategies` does.
    ///
    /// - Parameter strategies: The strategies, any of which flushes.
    public init<each Strategy: BatchStrategy>(_ strategies: repeat each Strategy) {
        var all = [any BatchStrategy]()
        for strategy in repeat each strategies {
            all.append(strategy)
        }
        self.strategies = all
    }

    public func flushes<Element>(pending: [Element]) -> Bool {
        strategies.contains { $0.flushes(pending: pending) }
    }

    public func run(_ flusher: BatchFlusher) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for strategy in strategies {
                group.addTask { try await strategy.run(flusher) }
            }
            try await group.waitForAll()
        }
    }
}

extension BatchStrategy where Self == EitherBatchStrategy {
    /// Flushes when any of the given strategies does.
    ///
    /// ## Example
    /// ```swift
    /// let flush = PassthroughSubject<Void>()
    /// let batches = events.batch(strategy: .either(
    ///     .count(10),
    ///     .time(interval: .milliseconds(500), clock: ContinuousClock()),
    ///     .signal(flush)))
    /// ```
    ///
    /// - Parameter strategies: The strategies, any of which flushes.
    /// - Returns: An ``EitherBatchStrategy``.
    public static func either<each Strategy: BatchStrategy>(_ strategies: repeat each Strategy)
        -> EitherBatchStrategy
    {
        EitherBatchStrategy(repeat each strategies)
    }
}
