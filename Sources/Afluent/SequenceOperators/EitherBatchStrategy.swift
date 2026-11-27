//
//  EitherBatchStrategy.swift
//  Afluent
//

import Foundation

/// A ``BatchStrategy`` that flushes when any of several strategies does.
///
/// Every flush starts all of them over, whichever one caused it. A strategy among them that
/// throws ends the batched sequence with its error at once, and the others are cancelled.
///
/// ## Example
/// ```swift
/// let flush = PassthroughSubject<Void>()
/// for try await batch in events.batch(strategy: .either(
///     .count(10),
///     .time(interval: .milliseconds(500), clock: ContinuousClock()),
///     .signal(flush))) {
///     send(batch) // At most 10 events, at most half a second old
/// }
/// ```
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
public struct EitherBatchStrategy<Element>: BatchStrategy {
    // A constrained existential, which is why batching needs iOS 16. Not a variadic generic type
    // (`EitherBatchStrategy<each S>`): those need the iOS 17 / macOS 14 runtime.
    /// The strategies, any of which flushes.
    public let strategies: [any BatchStrategy<Element>]

    // A variadic of existentials rather than a parameter pack: a pack can't yet require each
    // strategy's `Element` to be the same type ("same-element requirements are not yet
    // supported"). `first` makes at least one strategy required.
    /// Creates a strategy that flushes when any of the given strategies does.
    ///
    /// - Parameters:
    ///   - first: A strategy that flushes, batching `Element`.
    ///   - rest: More strategies, any of which flushes.
    public init(_ first: any BatchStrategy<Element>, _ rest: any BatchStrategy<Element>...) {
        self.init([first] + rest)
    }

    init(_ strategies: [any BatchStrategy<Element>]) {
        self.strategies = strategies
        // Each child is opened here, once, so every element calls it on its concrete type.
        self.flushChecks = strategies.map { Self.flushCheck(for: $0) }
    }

    /// Each strategy's `flushes(pending:)`, called on its concrete type.
    private let flushChecks: [@Sendable ([Element]) -> Bool]

    public func flushes(pending: [Element]) -> Bool {
        // A loop, not `contains(where:)`: unspecialized here, that cost two allocations per
        // element and strategy.
        for flushes in flushChecks where flushes(pending) {
            return true
        }
        return false
    }

    private static func flushCheck<Strategy: BatchStrategy<Element>>(for strategy: Strategy)
        -> @Sendable ([Element]) -> Bool
    {
        { strategy.flushes(pending: $0) }
    }

    public func run(_ flusher: BatchFlusher) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for strategy in strategies {
                group.addTask { try await strategy.run(flusher) }
            }
            // Not `waitForAll()`: it waits for every child, an endless timer included, before
            // forwarding an error, so a failing signal couldn't end the batched sequence.
            do {
                while try await group.next() != nil {}
            } catch {
                group.cancelAll()
                throw error
            }
        }
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
extension BatchStrategy {
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
    /// - Parameters:
    ///   - first: A strategy that flushes.
    ///   - rest: More strategies, any of which flushes.
    /// - Returns: An ``EitherBatchStrategy``.
    public static func either<Batched>(
        _ first: any BatchStrategy<Batched>, _ rest: any BatchStrategy<Batched>...
    ) -> EitherBatchStrategy<Batched>
    where Self == EitherBatchStrategy<Batched> {
        EitherBatchStrategy([first] + rest)
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
extension EitherBatchStrategy: ValidatedBatchStrategy {
    func validate() throws {
        for case let strategy as any ValidatedBatchStrategy in strategies {
            try strategy.validate()
        }
    }
}
