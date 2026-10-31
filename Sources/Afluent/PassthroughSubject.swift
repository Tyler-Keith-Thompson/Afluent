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
///   not be missed, wait until the consumer has asked for its first value before sending, for example with
///   `handleEvents(receiveNext:)`. (`receiveMakeIterator` is too early: it runs before the upstream iterator,
///   and so the subscription, is created.)
///
/// ## Example
/// ```swift
/// let subject = PassthroughSubject<Int>()
/// let subscribed = SingleValueSubject<Void>()
///
/// subject.send(0) // No subscribers yet, so this value is discarded.
///
/// Task {
///     for try await value in subject.handleEvents(receiveNext: { try? subscribed.send() }) {
///         print("Received value: \(value)") // prints 1, then 2
///     }
/// }
///
/// try await subscribed.execute()
/// subject.send(1)
/// subject.send(2)
/// subject.send(completion: .finished)
/// ```
public final class PassthroughSubject<Element: Sendable>: AsyncSequence, @unchecked Sendable {
    fileprivate struct Subscriber: Sendable {
        var buffer = [Element]()
        var terminal: Result<Element?, any Error>?
        var continuation: UnsafeContinuation<Result<Element?, any Error>, Never>?

        mutating func drain() {
            guard let continuation else { return }
            if !buffer.isEmpty {
                self.continuation = nil
                continuation.resume(returning: .success(buffer.removeFirst()))
            } else if let terminal {
                self.continuation = nil
                // A failure is delivered once; afterwards the subscriber is simply finished.
                self.terminal = .success(nil)
                continuation.resume(returning: terminal)
            }
        }
    }

    fileprivate struct State: Sendable {
        var nextID = 0
        var subscribers = [Int: Subscriber]()
        var finishedResult: Result<Element?, any Error>?

        mutating func emit(_ update: (inout Subscriber) -> Void) {
            for id in subscribers.keys {
                update(&subscribers[id]!)
                subscribers[id]!.drain()
            }
        }
    }

    private let state = ManagedCriticalState(State())

    /// Creates a `PassthroughSubject`.
    public init() {}

    public struct Iterator: AsyncIteratorProtocol, @unchecked Sendable {
        let subscription: Subscription

        public mutating func next() async throws -> Element? {
            try await subscription.next()
        }
    }

    /// Subscribes a new consumer. Values sent from now on are buffered for it until it consumes them.
    public func makeAsyncIterator() -> Iterator {
        Iterator(subscription: Subscription(state: state))
    }

    /// Sends a new value to every current subscriber. If there are no subscribers, the value is discarded.
    /// - Parameter element: The new value to broadcast.
    public func send(_ element: Element) {
        state.withCriticalRegion { state in
            guard state.finishedResult == nil else { return }
            state.emit { $0.buffer.append(element) }
        }
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
        state.withCriticalRegion { state in
            guard state.finishedResult == nil else { return }
            let result: Result<Element?, any Error>
            switch completion {
                case .finished: result = .success(nil)
                case .failure(let error): result = .failure(error)
            }
            state.finishedResult = result
            state.emit { $0.terminal = result }
        }
    }
}

extension PassthroughSubject {
    final class Subscription: @unchecked Sendable {
        private let state: ManagedCriticalState<PassthroughSubject.State>
        private let id: Int?
        private let finished: Result<Element?, any Error>?

        fileprivate init(state: ManagedCriticalState<PassthroughSubject.State>) {
            self.state = state
            (id, finished) = state.withCriticalRegion { state in
                if let finished = state.finishedResult {
                    return (nil, finished)
                }
                defer { state.nextID += 1 }
                state.subscribers[state.nextID] = PassthroughSubject.Subscriber()
                return (state.nextID, nil)
            }
        }

        deinit {
            guard let id else { return }
            _ = state.withCriticalRegion { $0.subscribers.removeValue(forKey: id) }
        }

        func next() async throws -> Element? {
            guard let id else { return try finished?.get() }
            let result = await withTaskCancellationHandler { [state] in
                await withUnsafeContinuation {
                    (continuation: UnsafeContinuation<Result<Element?, any Error>, Never>) in
                    state.withCriticalRegion { state in
                        guard state.subscribers[id] != nil else {
                            continuation.resume(returning: .success(nil))
                            return
                        }
                        state.subscribers[id]!.continuation = continuation
                        state.subscribers[id]!.drain()
                    }
                }
            } onCancel: { [state] in
                let continuation = state.withCriticalRegion {
                    $0.subscribers.removeValue(forKey: id)?.continuation
                }
                continuation?.resume(returning: .success(nil))
            }
            return try result.get()
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
