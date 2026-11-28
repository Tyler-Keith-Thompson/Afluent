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
/// ``SignalBatchStrategy`` (over a sequence or a unit of work) and ``EitherBatchStrategy``,
/// spelled `.count(_:)`, `.time(interval:clock:tolerance:)`, `.signal(_:)` and `.either(_:_:)`
/// where a strategy is expected.
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
/// batched sequence ends. A custom strategy composes with the built-in ones in `.either(_:_:)`.
/// `Element` is the batched sequence's element: name it in `flushes(pending:)`, or make the
/// strategy generic over it when only ``run(_:)`` matters.
///
/// ```swift
/// /// Flushes after each line, so every batch ends at a line break.
/// struct LineBatchStrategy: BatchStrategy {
///     func flushes(pending: [Character]) -> Bool {
///         pending.last == "\n"
///     }
/// }
///
/// // A batch per line, or whatever has arrived after a second without one.
/// let lines = characters.batch(strategy: .either(
///     LineBatchStrategy(),
///     .time(interval: .seconds(1), clock: ContinuousClock())))
/// ```
///
/// Batching needs iOS 16, Mac Catalyst 16, macOS 13, tvOS 16, watchOS 9 or visionOS 1.
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
public protocol BatchStrategy<Element>: Sendable {
    /// The type of the elements the strategy batches: the upstream sequence's element.
    associatedtype Element

    /// Whether to flush now that an element has joined the pending ones.
    ///
    /// Called after every element, with the batched sequence's lock held, so it should be quick
    /// and must not call a ``BatchFlusher``. The default returns `false`.
    ///
    /// - Parameter pending: The elements gathered since the last flush, the newest last; never
    ///   empty.
    /// - Returns: `true` to emit `pending` now.
    /// - Complexity: Called once per element; keep it O(1) where you can.
    func flushes(pending: [Element]) -> Bool

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

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
extension BatchStrategy {
    public func flushes(pending: [Element]) -> Bool { false }

    public func run(_ flusher: BatchFlusher) async throws {}
}

/// A built-in strategy whose arguments can be out of range, checked before batching starts.
///
/// Internal, so the public protocol stays two requirements with defaults. A strategy that
/// conforms is checked when it is the batched sequence's strategy or one of
/// ``EitherBatchStrategy``'s; one a custom strategy wraps is not.
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
protocol ValidatedBatchStrategy {
    /// Throws the typed error for the first argument that is out of range.
    func validate() throws
}
