//
//  SignalBatchStrategy.swift
//  Afluent
//

import Foundation

/// A ``BatchStrategy`` that flushes each time a sequence produces an element.
///
/// The signal's elements are ignored; only their arrival counts. Use it with a
/// ``PassthroughSubject`` or a ``CurrentValueSubject`` to flush on demand. A value already
/// available at subscription, such as a `CurrentValueSubject`'s current value, fires when the
/// signal's task subscribes. That task starts alongside the upstream's, so elements may already
/// have arrived and the first batch may be short. A signal that finishes stops firing and the
/// batches go on until the upstream finishes; a signal that throws ends the batched sequence with
/// its error.
///
/// ## Example
/// ```swift
/// let flush = PassthroughSubject<Void>()
/// for try await lines in logLines.batch(strategy: .signal(flush)) {
///     write(lines)
/// }
/// // Elsewhere, when the app moves to the background:
/// flush.send()
/// ```
public struct SignalBatchStrategy<Signal: AsyncSequence & Sendable>: BatchStrategy {
    /// The sequence whose elements flush the batch.
    public let signal: Signal

    /// Creates a strategy that flushes on every element of `signal`.
    ///
    /// - Parameter signal: The sequence whose elements flush the batch.
    public init(_ signal: Signal) {
        self.signal = signal
    }

    public func run(_ flusher: BatchFlusher) async throws {
        for try await _ in signal {
            // A signal that ignores cancellation would otherwise be read for ever after the
            // batched sequence ends.
            guard !Task.isCancelled else { return }
            flusher.flush()
        }
    }
}

extension BatchStrategy {
    /// Flushes each time the given sequence produces an element.
    ///
    /// ## Example
    /// ```swift
    /// let flush = PassthroughSubject<Void>()
    /// for try await lines in logLines.batch(strategy: .signal(flush)) {
    ///     write(lines)
    /// }
    /// ```
    ///
    /// - Parameter signal: The sequence whose elements flush the batch.
    /// - Returns: A ``SignalBatchStrategy``.
    public static func signal<Signal>(_ signal: Signal) -> SignalBatchStrategy<Signal>
    where Self == SignalBatchStrategy<Signal> {
        SignalBatchStrategy(signal)
    }
}
