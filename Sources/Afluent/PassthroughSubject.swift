//
//  PassthroughSubject.swift
//  Afluent
//
//  Created by Tyler Thompson on 10/12/24.
//

/// A subject that broadcasts values to multiple consumers without storing a current value.
/// Unlike `CurrentValueSubject`, `PassthroughSubject` does not retain the most recent value.
/// This is an `AsyncSequence` that allows multiple tasks to asynchronously consume values and mimics Combine's PassthroughSubject.
///
/// ## Subscribing
/// A consumer subscribes when its iterator is created, which is when a `for try await` loop over the subject
/// (or over an operator chain built on it) begins. From then on, every value sent is buffered for that consumer
/// until it is consumed, so a consumer that is slower than the sender still sees every value, in order.
///
/// Values sent while there are no subscribers are discarded; they are never replayed to a later consumer.
///
/// - Important: Starting a `Task` that iterates the subject does not mean it has subscribed yet. If values must
///   not be missed, wait until the consumer has subscribed before sending, for example with
///   `handleEvents(receiveMakeIterator:)`.
///
/// ## Example
/// ```swift
/// let subject = PassthroughSubject<Int>()
/// let subscribed = SingleValueSubject<Void>()
///
/// subject.send(0) // No subscribers yet, so this value is discarded.
///
/// Task {
///     for try await value in subject.handleEvents(receiveMakeIterator: { try? subscribed.send() }) {
///         print("Received value: \(value)") // prints 1, then 2
///     }
/// }
///
/// try await subscribed.execute()
/// subject.send(1)
/// subject.send(2)
/// subject.send(completion: .finished)
/// ```
public final class PassthroughSubject<Element: Sendable>: AsyncSequence, Sendable {
    private let broadcaster = SubjectBroadcaster<Element>()

    /// Creates a `PassthroughSubject`.
    public init() {}

    public struct Iterator: AsyncIteratorProtocol, Sendable {
        let subscription: SubjectBroadcaster<Element>.Subscription

        public mutating func next() async throws -> Element? {
            try await subscription.next()
        }
    }

    /// Subscribes a new consumer. Values sent from now on are buffered for it until it consumes them.
    public func makeAsyncIterator() -> Iterator {
        Iterator(subscription: broadcaster.subscribe())
    }

    /// Sends a new value to every current subscriber. If there are no subscribers, the value is discarded.
    /// - Parameter element: The new value to broadcast.
    public func send(_ element: Element) {
        broadcaster.send(element)
    }

    /// Sends a value to every current subscriber when the subject's `Element` is `Void`.
    /// This is useful for signaling purposes rather than data transmission.
    public func send() where Element == Void {
        send(())
    }

    /// Completes the subject, preventing any further values from being sent.
    /// Current subscribers receive the completion after any values already buffered for them, and consumers that
    /// start iterating afterwards receive it immediately.
    /// - Parameter completion: The completion event, either `.finished` or `.failure(Error)`.
    public func send(completion: Completion<any Error>) {
        switch completion {
            case .finished: broadcaster.finish(.success(nil))
            case .failure(let error): broadcaster.finish(.failure(error))
        }
    }
}

extension PassthroughSubject {
    /// Represents the completion event of a subject, which can either succeed or fail with an error.
    public enum Completion<Failure: Error> {
        case finished
        case failure(Failure)
    }
}
