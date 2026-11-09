//
//  CurrentValueSubject.swift
//  Afluent
//
//  Created by Tyler Thompson on 10/12/24.
//

/// A subject that broadcasts its current value and all subsequent values to multiple consumers.
/// It can also handle completion events, including normal termination and failure with an error.
/// This is an `AsyncSequence` that allows multiple tasks to asynchronously consume values and mimics Combine's CurrentValueSubject.
///
/// ## Subscribing
/// A consumer subscribes when its iterator is created, which is when a `for try await` loop over the subject
/// (or over an operator chain built on it) begins. It first receives the value that is current at that moment,
/// then every value sent afterwards, in order; values are buffered for it until it consumes them. Values sent
/// before it subscribed are not replayed. A consumer that subscribes after completion receives only the completion.
///
/// ## Example
/// ```swift
/// let subject = CurrentValueSubject(0)
/// let subscribed = SingleValueSubject<Void>()
///
/// subject.send(1) // Becomes the current value; no one is subscribed yet.
///
/// Task {
///     for try await value in subject.handleEvents(receiveMakeIterator: { try? subscribed.send() }) {
///         print("Received value: \(value)") // prints 1, then 2, then 3
///     }
/// }
///
/// try await subscribed.execute()
/// subject.send(2)
/// subject.send(3)
/// subject.send(completion: .finished)
/// ```
public final class CurrentValueSubject<Element: Sendable>: AsyncSequence, Sendable {
    private let broadcaster: SubjectBroadcaster<Element>

    /// The current value of the subject. This property is thread-safe.
    /// Updating this property will also broadcast the new value to all active consumers.
    public var value: Element {
        get {
            // Always set: the broadcaster is created with a current value.
            broadcaster.current!
        }
        set { broadcaster.setCurrent(newValue) }
    }

    /// Creates a `CurrentValueSubject` with an initial value.
    /// - Parameter value: The initial value that will be broadcast to consumers.
    public init(_ value: Element) {
        broadcaster = SubjectBroadcaster(current: value)
    }

    /// Creates a `CurrentValueSubject` with an initial `Void` value.
    public convenience init() where Element == Void {
        self.init(())
    }

    public struct Iterator: AsyncIteratorProtocol, Sendable {
        let subscription: SubjectBroadcaster<Element>.Subscription

        public mutating func next() async throws -> Element? {
            try await subscription.next()
        }
    }

    /// Subscribes a new consumer. It receives the current value, then every value sent from now on.
    public func makeAsyncIterator() -> Iterator {
        Iterator(subscription: broadcaster.subscribe())
    }

    /// Sends a new value to all current consumers and makes it the current value.
    /// - Parameter element: The new value to broadcast.
    public func send(_ element: Element) {
        broadcaster.send(element)
    }

    /// Sends a value to consumers when the subject's `Element` is `Void`.
    /// This is useful for signaling purposes rather than data transmission.
    public func send() where Element == Void {
        send(())
    }

    /// Completes the subject, preventing any further values from being sent.
    /// Current consumers receive the completion after any values already buffered for them, and consumers that
    /// start iterating afterwards receive it immediately.
    /// - Parameter completion: The completion event, either `.finished` or `.failure(Error)`.
    public func send(completion: Completion<any Error>) {
        switch completion {
            case .finished: broadcaster.finish(.success(nil))
            case .failure(let error): broadcaster.finish(.failure(error))
        }
    }
}

extension CurrentValueSubject {
    /// Represents the completion event of a subject, which can either succeed or fail with an error.
    public enum Completion<Failure: Error> {
        case finished
        case failure(Failure)
    }
}

