//
//  SubjectSubscription.swift
//  Afluent
//

/// A place in a ``PassthroughSubject`` or ``CurrentValueSubject`` that a consumer can stop waiting on and come back
/// to, keeping every value sent in between.
///
/// Make one with the subject's `makeSubscription()`. It subscribes when it is made, exactly like the subject's
/// iterator: a `CurrentValueSubject`'s subscription starts with the current value, and every value sent after that
/// is buffered for it, without limit, until ``next()`` returns it.
///
/// The difference is cancellation. Cancelling a task waiting in an iterator's `next()` ends that iterator's
/// subscription and discards its buffer. Cancelling a task waiting in a subscription's ``next()`` throws
/// `CancellationError` from that call only: the subscription stays subscribed, and a later ``next()`` returns the
/// values sent before and after the cancellation, in order. That suits a consumer that runs in rounds, such as a
/// batch run that is cancelled and started again, and must not miss what was sent between rounds.
///
/// The subscription unsubscribes when its last copy is released. It conforms to `AsyncIteratorProtocol`, so an
/// operator can read it through ``AsyncIteratorSequence``; a cancelled read then ends that operator's run with
/// `CancellationError` and leaves the subscription for the next run.
///
/// ## Example
/// ```swift
/// let events = PassthroughSubject<String>()
/// let subscription = events.makeSubscription()
///
/// let firstRound = Task { try await subscription.next() }
/// firstRound.cancel() // Throws CancellationError from that wait; nothing is lost.
/// _ = await firstRound.result
///
/// events.send("launch")
/// events.send("login")
/// let first = try await subscription.next()  // "launch"
/// let second = try await subscription.next() // "login"
/// ```
///
/// - Important: Wait on a subscription from one task at a time. Calling ``next()`` while another call on the same
///   subscription is still waiting traps.
public struct SubjectSubscription<Element: Sendable>: AsyncIteratorProtocol, Sendable {
    let subscription: SubjectBroadcaster<Element>.Subscription

    /// Waits for the next value sent to the subject.
    ///
    /// - Returns: The next value, or `nil` once the subject has finished and every buffered value has been
    ///   returned.
    /// - Throws: The error the subject finished with, after every buffered value has been returned; or
    ///   `CancellationError` if the calling task is cancelled before a value arrives, which leaves the subscription
    ///   and its buffer as they were.
    /// - Precondition: No other call to `next()` on this subscription is waiting.
    public func next() async throws -> Element? {
        try await subscription.next()
    }
}
