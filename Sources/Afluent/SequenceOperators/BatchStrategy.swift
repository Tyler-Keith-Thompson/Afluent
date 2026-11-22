//
//  BatchStrategy.swift
//  Afluent
//

import Foundation

/// When ``_Concurrency/AsyncSequence/batch(strategy:)`` emits the elements it has gathered.
///
/// A strategy flushes the pending elements as one array when it fires: on a count, a timer or a
/// signal, or, with ``either(_:)``, whichever of several fires first. After every flush, whatever
/// its cause, each strategy starts over: counts from zero, timers from the moment of the flush.
/// A timer or signal that fires with nothing pending emits nothing, but still starts every
/// strategy over.
///
/// ## Example
/// ```swift
/// // Up to 100 events per upload, and at least one upload every 5 seconds while events arrive.
/// let strategy = BatchStrategy.either(
///     .count(100),
///     .time(interval: .seconds(5), clock: ContinuousClock()))
/// for try await events in analyticsEvents.batch(strategy: strategy) {
///     try await upload(events)
/// }
/// ```
public struct BatchStrategy: Sendable {
    /// The smallest count that flushes, or `nil` when no count is part of this strategy.
    let count: Int?
    /// The timers and signals that flush when they fire.
    let triggers: [Trigger]

    /// Flushes whenever the given number of elements is pending.
    ///
    /// ## Example
    /// ```swift
    /// for try await pair in [1, 2, 3, 4, 5].async.batch(strategy: .count(2)) {
    ///     print(pair) // Prints [1, 2], then [3, 4], then [5]
    /// }
    /// ```
    ///
    /// - Parameter count: The number of elements in every batch but the last, which holds what
    ///   is pending when the upstream finishes.
    /// - Returns: A strategy that flushes every `count` elements.
    /// - Precondition: `count` is at least 1.
    public static func count(_ count: Int) -> BatchStrategy {
        precondition(count >= 1, "A batch's count must be at least 1, not \(count)")
        return BatchStrategy(count: count, triggers: [])
    }

    /// Flushes each time the interval passes on the given clock.
    ///
    /// The timer starts when iteration begins and starts over after every flush, including
    /// flushes another strategy in ``either(_:)`` caused, so a batch is never older than
    /// `interval`. When the interval passes with nothing pending, nothing is emitted and the
    /// timer starts over.
    ///
    /// ## Example
    /// ```swift
    /// let strategy = BatchStrategy.time(interval: .seconds(1), clock: ContinuousClock())
    /// for try await readings in sensor.readings.batch(strategy: strategy) {
    ///     print(readings) // The readings of each second that had any
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - interval: How long elements gather before they are flushed.
    ///   - clock: The clock that measures the interval.
    ///   - tolerance: The tolerance of the timer's sleeps. Defaults to `nil`.
    /// - Returns: A strategy that flushes every `interval`.
    /// - Precondition: `interval` is greater than zero.
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    public static func time<C: Clock>(
        interval: C.Duration, clock: C, tolerance: C.Duration? = nil
    ) -> BatchStrategy {
        precondition(interval > .zero, "A batch's interval must be greater than zero")
        let trigger = Trigger {
            let timer = CriticalState(TimerState(start: clock.now, epoch: 0))
            return ArmedTrigger(
                reset: {
                    timer.withCriticalRegion { timer in
                        timer.start = clock.now
                        timer.epoch &+= 1
                    }
                },
                run: { fire in
                    while true {
                        let (deadline, epoch) = timer.withCriticalRegion {
                            ($0.start.advanced(by: interval), $0.epoch)
                        }
                        try await clock.sleep(until: deadline, tolerance: tolerance)
                        // A flush while this sleep ran moved the deadline; it fires only if none did.
                        fire { timer.withCriticalRegion { $0.epoch == epoch } }
                    }
                })
        }
        return BatchStrategy(count: nil, triggers: [trigger])
    }

    /// Flushes each time the given sequence produces an element.
    ///
    /// The signal's elements are ignored; only their arrival counts. Use it with a
    /// ``PassthroughSubject`` or a ``CurrentValueSubject`` to flush on demand. A value already
    /// available at subscription, such as a `CurrentValueSubject`'s current value, fires when the
    /// signal's task subscribes. That task starts alongside the upstream's, so elements may already
    /// have arrived and the first batch may be short. A signal that finishes stops firing and the
    /// batches go on until the upstream finishes; a signal that throws ends the batched sequence
    /// with its error.
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
    ///
    /// - Parameter signal: The sequence whose elements flush the batch.
    /// - Returns: A strategy that flushes on every element of `signal`.
    public static func signal<Signal: AsyncSequence & Sendable>(_ signal: Signal) -> BatchStrategy {
        let trigger = Trigger {
            ArmedTrigger(
                reset: {},
                run: { fire in
                    for try await _ in signal {
                        fire { true }
                    }
                })
        }
        return BatchStrategy(count: nil, triggers: [trigger])
    }

    /// Flushes once, when the given subject is sent a value.
    ///
    /// The batched sequence listens to the subject without owning it: when the batched sequence
    /// ends or is cancelled, the subject stays pending for its other awaiters. A subject sent an
    /// error ends the batched sequence with that error, except `CancellationError` (as when another
    /// awaiter cancels the subject): then the signal stops firing and the batches go on until the
    /// upstream finishes. A subject sent a value before iteration begins fires when the signal's
    /// task subscribes, which may come after elements have arrived, so the first batch may be
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
    /// - Returns: A strategy that flushes when `subject` is sent a value.
    public static func signal<Success>(_ subject: SingleValueSubject<Success>) -> BatchStrategy {
        let trigger = Trigger {
            ArmedTrigger(
                reset: {},
                run: { fire in
                    do {
                        _ = try await subject.observe()
                    } catch is CancellationError {
                        // A subject someone else cancelled will never send: the signal is over,
                        // not failed. When the batch's own task is cancelled, this ends it too.
                        return
                    }
                    fire { true }
                })
        }
        return BatchStrategy(count: nil, triggers: [trigger])
    }

    /// Flushes when any of the given strategies fires.
    ///
    /// Every flush starts all of them over, whichever one caused it. With no strategies, the
    /// batched sequence emits everything in one array when the upstream finishes.
    ///
    /// ## Example
    /// ```swift
    /// let flush = PassthroughSubject<Void>()
    /// let strategy = BatchStrategy.either(
    ///     .count(10),
    ///     .time(interval: .milliseconds(500), clock: ContinuousClock()),
    ///     .signal(flush))
    /// for try await batch in events.batch(strategy: strategy) {
    ///     send(batch) // At most 10 events, at most half a second old
    /// }
    /// ```
    ///
    /// - Parameter strategies: The strategies, any of which flushes.
    /// - Returns: A strategy that flushes when any of `strategies` fires.
    public static func either(_ strategies: BatchStrategy...) -> BatchStrategy {
        BatchStrategy(
            count: strategies.lazy.compactMap(\.count).min(),
            triggers: strategies.flatMap(\.triggers))
    }
}

extension BatchStrategy {
    /// A timer or a signal, armed afresh each time a batched sequence starts iterating.
    struct Trigger: Sendable {
        let arm: @Sendable () -> ArmedTrigger
    }

    /// A trigger for one iteration of a batched sequence.
    struct ArmedTrigger: Sendable {
        /// Starts the trigger over after a flush. Called with the batch's lock held.
        let reset: @Sendable () -> Void
        /// Runs until the trigger ends or its task is cancelled, calling `fire` each time it
        /// fires. `fire` evaluates its argument with the batch's lock held and flushes only if it
        /// returns `true`, so a firing that a concurrent flush made stale is dropped.
        let run: @Sendable (_ fire: @Sendable (_ isDue: () -> Bool) -> Void) async throws -> Void
    }

    /// When a time strategy's interval began, and how many times it has started over.
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    struct TimerState<Instant: InstantProtocol>: Sendable {
        var start: Instant
        var epoch: Int
    }
}
