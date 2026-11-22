//
//  SingleValueSubjectBatchStrategy.swift
//  Afluent
//

import Foundation

/// A ``BatchStrategy`` that flushes once, when a ``SingleValueSubject`` is sent a value.
///
/// The batched sequence listens to the subject without owning it: when the batched sequence ends
/// or is cancelled, the subject stays pending for its other awaiters. A subject sent an error
/// ends the batched sequence with that error, except `CancellationError` (as when another awaiter
/// cancels the subject): then the signal stops firing and the batches go on until the upstream
/// finishes. A subject sent a value before iteration begins fires when the strategy's task
/// subscribes, which may come after elements have arrived, so the first batch may be short.
///
/// ## Example
/// ```swift
/// let shutdown = SingleValueSubject<Void>()
/// for try await messages in inbox.batch(strategy: .either(.count(50), .signal(shutdown))) {
///     store(messages)
/// }
/// // Elsewhere: flush whatever is pending before shutting down.
/// try shutdown.send()
/// ```
// A type of its own rather than an initializer on SignalBatchStrategy: a SingleValueSubject is a
// unit of work, not a sequence, so it can't be that type's `Signal`.
public struct SingleValueSubjectBatchStrategy<Success: Sendable>: BatchStrategy {
    /// The subject whose value flushes the batch.
    public let subject: SingleValueSubject<Success>

    /// Creates a strategy that flushes when `subject` is sent a value.
    ///
    /// - Parameter subject: The subject whose value flushes the batch.
    public init(_ subject: SingleValueSubject<Success>) {
        self.subject = subject
    }

    public func run(_ flusher: BatchFlusher) async throws {
        do {
            _ = try await subject.observe()
        } catch is CancellationError {
            // A subject someone else cancelled will never send: the signal is over, not failed.
            // When the batch's own task is cancelled, this ends it too.
            return
        }
        flusher.flush()
    }
}

extension BatchStrategy {
    /// Flushes once, when the given subject is sent a value.
    ///
    /// ## Example
    /// ```swift
    /// let shutdown = SingleValueSubject<Void>()
    /// for try await messages in inbox.batch(strategy: .either(.count(50), .signal(shutdown))) {
    ///     store(messages)
    /// }
    /// ```
    ///
    /// - Parameter subject: The subject whose value flushes the batch.
    /// - Returns: A ``SingleValueSubjectBatchStrategy``.
    public static func signal<Success>(_ subject: SingleValueSubject<Success>)
        -> SingleValueSubjectBatchStrategy<Success>
    where Self == SingleValueSubjectBatchStrategy<Success> {
        SingleValueSubjectBatchStrategy(subject)
    }
}
