//
//  BatchFlusher.swift
//  Afluent
//

import Foundation

/// The handle a ``BatchStrategy`` flushes a batched sequence through from ``BatchStrategy/run(_:)``.
///
/// ## Example
/// ```swift
/// /// Flushes whenever the app moves to the background.
/// struct BackgroundBatchStrategy: BatchStrategy {
///     let backgrounded: PassthroughSubject<Void>
///
///     func run(_ flusher: BatchFlusher) async throws {
///         for await _ in backgrounded {
///             flusher.flush()
///         }
///     }
/// }
/// ```
public struct BatchFlusher: Sendable {
    let flushIfDue: @Sendable (_ isDue: () -> Bool) -> Void
    let observeFlushes: @Sendable (_ observer: @escaping @Sendable () -> Void) -> Void

    /// Emits the pending elements, if there are any, and starts every strategy over.
    ///
    /// Does nothing once the batched sequence has ended.
    public func flush() {
        flushIfDue { true }
    }

    /// Flushes if `isDue` returns `true` when checked, with the batched sequence's lock held.
    ///
    /// Use it when another flush may have made this one stale while the strategy waited: a timer
    /// whose deadline a flush moved checks that no flush happened since it went to sleep.
    ///
    /// - Parameter isDue: Whether the flush still stands. It must be quick and must not call
    ///   this flusher.
    public func flush(if isDue: () -> Bool) {
        flushIfDue(isDue)
    }

    /// Calls `observer` after every flush, whichever strategy caused it, so a strategy can start
    /// over (a timer restarting from the flush).
    ///
    /// The observer runs with the batched sequence's lock held, so it must be quick and must not
    /// call this flusher. Flushes before it is added aren't reported.
    ///
    /// - Parameter observer: Called after each flush, for as long as the batched sequence is
    ///   iterated.
    public func onFlush(_ observer: @escaping @Sendable () -> Void) {
        observeFlushes(observer)
    }
}
