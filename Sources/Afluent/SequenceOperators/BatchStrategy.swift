//
//  BatchStrategy.swift
//  Afluent
//

import Foundation

/// When ``_Concurrency/AsyncSequence/batch(strategy:)`` emits the elements it has gathered.
///
/// A strategy flushes the pending elements as one array in either of two ways: when an element
/// arrives, by returning `true` from ``flushes(pending:)``, or on events of its own (a timer, a
/// signal), by calling ``BatchFlusher/flush()`` from ``run(_:)``. After every flush, whatever its
/// cause, each strategy starts over. A flush with nothing pending emits nothing.
///
/// The built-in strategies are ``CountBatchStrategy``, ``TimeBatchStrategy``,
/// ``SignalBatchStrategy``, ``SingleValueSubjectBatchStrategy`` and ``EitherBatchStrategy``,
/// spelled `.count(_:)`, `.time(interval:clock:tolerance:)`, `.signal(_:)` and `.either(_:)` where
/// a strategy is expected.
///
/// ```swift
/// // Up to 100 events per upload, and at least one upload every 5 seconds while events arrive.
/// let events = analyticsEvents.batch(strategy: .either(
///     .count(100),
///     .time(interval: .seconds(5), clock: ContinuousClock())))
/// for try await batch in events {
///     try await upload(batch)
/// }
/// ```
///
/// ## Writing a strategy
///
/// Conform a type to `BatchStrategy` and implement either requirement, or both; each has a
/// default that never flushes. Implement ``flushes(pending:)`` to decide from the pending
/// elements, after each one arrives. Implement ``run(_:)`` to flush on events of your own: it
/// runs in a task of its own while the batched sequence is iterated, and is cancelled when the
/// batched sequence ends. A custom strategy composes with the built-in ones in `.either(_:)`.
///
/// ```swift
/// /// Flushes after each line, so every batch ends at a line break.
/// struct LineBatchStrategy: BatchStrategy {
///     func flushes<Element>(pending: [Element]) -> Bool {
///         (pending.last as? Character) == "\n"
///     }
/// }
///
/// // A batch per line, or whatever has arrived after a second without one.
/// let lines = characters.batch(strategy: .either(
///     LineBatchStrategy(),
///     .time(interval: .seconds(1), clock: ContinuousClock())))
/// ```
public protocol BatchStrategy: Sendable {
    /// Whether to flush now that an element has joined the pending ones.
    ///
    /// Called after every element, with the batched sequence's lock held, so it should be quick
    /// and must not call a ``BatchFlusher``. The default returns `false`.
    ///
    /// - Parameter pending: The elements gathered since the last flush, the newest last; never
    ///   empty.
    /// - Returns: `true` to emit `pending` now.
    /// - Complexity: Called once per element; keep it O(1) where you can.
    func flushes<Element>(pending: [Element]) -> Bool

    /// Flushes on the strategy's own events, for as long as the batched sequence is iterated.
    ///
    /// Runs in a task of its own, started when iteration begins and cancelled when the batched
    /// sequence ends. Returning stops this strategy's flushes and the batches go on; throwing
    /// ends the batched sequence with the error. The default returns at once.
    ///
    /// - Parameter flusher: The handle to flush the batch through, and to hear of every flush.
    /// - Throws: An error that ends the batched sequence.
    func run(_ flusher: BatchFlusher) async throws
}

extension BatchStrategy {
    public func flushes<Element>(pending: [Element]) -> Bool { false }

    public func run(_ flusher: BatchFlusher) async throws {}
}
