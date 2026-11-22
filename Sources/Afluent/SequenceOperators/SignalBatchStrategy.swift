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
/// its error, except `CancellationError` while the batched sequence is still running (a
/// ``SingleValueSubject`` someone else cancelled): then the signal stops firing and the batches go
/// on.
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
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
public struct SignalBatchStrategy<Element, Signal: AsyncSequence & Sendable>: BatchStrategy {
    /// The sequence whose elements flush the batch.
    public let signal: Signal

    /// Creates a strategy that flushes on every element of `signal`.
    ///
    /// - Parameter signal: The sequence whose elements flush the batch.
    public init(_ signal: Signal) {
        self.signal = signal
    }

    public func run(_ flusher: BatchFlusher) async throws {
        do {
            for try await _ in signal {
                // A signal that ignores cancellation would otherwise be read for ever after the
                // batched sequence ends.
                guard !Task.isCancelled else { return }
                flusher.flush()
            }
        } catch is CancellationError {
            // A signal cancelled by someone else (a subject another awaiter cancelled) will never
            // fire again: it is over, not failed. When the batch's own task is cancelled, this
            // ends it too.
            return
        }
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
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
    public static func signal<Batched, Signal>(_ signal: Signal)
        -> SignalBatchStrategy<Batched, Signal>
    where Self == SignalBatchStrategy<Batched, Signal> {
        SignalBatchStrategy(signal)
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
extension BatchStrategy {
    /// Flushes once, when the given unit of work completes.
    ///
    /// The unit of work runs as the signal ``AsynchronousUnitOfWork/toAsyncSequence()``, so a unit
    /// that fails ends the batched sequence with its error. When the batched sequence ends first,
    /// the unit's work is cancelled; a unit whose work ignores cancellation keeps the batch's
    /// internal task alive until it returns, though the batched sequence itself ends at once. A
    /// ``SingleValueSubject`` takes ``signal(_:)-(SingleValueSubject<Success>)`` instead, which
    /// leaves the subject alone.
    ///
    /// ## Example
    /// ```swift
    /// let reachable = DeferredTask { try await server.waitUntilReachable() }
    /// for try await requests in outbox.batch(strategy: .either(.count(20), .signal(reachable))) {
    ///     try await send(requests)
    /// }
    /// ```
    ///
    /// - Parameter unit: The unit of work whose completion flushes the batch.
    /// - Returns: A ``SignalBatchStrategy`` over `unit.toAsyncSequence()`.
    // Disfavored so a SingleValueSubject, also a unit of work, takes its own overload: both
    // infer `Self` from their return types, which leaves the compiler no other way to rank them.
    @_disfavoredOverload
    public static func signal<Batched, Unit: AsynchronousUnitOfWork>(_ unit: Unit)
        -> SignalBatchStrategy<Batched, AsynchronousUnitOfWorkSequence<Unit>>
    where Self == SignalBatchStrategy<Batched, AsynchronousUnitOfWorkSequence<Unit>> {
        .signal(unit.toAsyncSequence())
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
extension BatchStrategy {
    /// Flushes once, when the given subject is sent a value.
    ///
    /// The batched sequence listens to the subject without owning it: when the batched sequence
    /// ends or is cancelled, its wait ends at once and the subject stays pending for its other
    /// awaiters. A subject sent an error ends the batched sequence with that error, except
    /// `CancellationError` (as when another awaiter cancels the subject): then the signal stops
    /// firing and the batches go on. A subject sent a value before iteration begins fires when the
    /// signal's task starts, which may come after elements have arrived, so the first batch may be
    /// short.
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
    ///
    /// - Parameter subject: The subject whose value flushes the batch.
    /// - Returns: A ``SignalBatchStrategy`` over the subject's value.
    // Erased because the sequence that listens without owning the subject is internal.
    public static func signal<Batched, Success>(_ subject: SingleValueSubject<Success>)
        -> SignalBatchStrategy<Batched, AsyncSequences.AnyAsyncSequence<Success>>
    where Self == SignalBatchStrategy<Batched, AsyncSequences.AnyAsyncSequence<Success>> {
        .signal(SingleValueSubjectObservation(subject: subject).eraseToAnyAsyncSequence())
    }
}
