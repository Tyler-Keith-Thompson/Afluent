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
/// ## Example
/// ```swift
/// let subject = CurrentValueSubject(0)
///
/// Task {
///     for try await value in subject {
///         print("Received value: \(value)")
///     }
/// }
///
/// subject.send(1)
/// subject.send(2)
/// subject.send(completion: .finished)
/// ```
public final class CurrentValueSubject<Element: Sendable>: AsyncSequence, @unchecked Sendable {
    class State: @unchecked Sendable {
        private let lock = Lock.allocate()
        private var _finishedResult: Result<Element?, any Error>?
        var finishedResult: Result<Element?, any Error>? {
            get { lock.withLock { _finishedResult } }
            set { lock.withLockVoid { _finishedResult = newValue } }
        }

        var _value: Element
        var value: Element {
            get { lock.withLock { _value } }
            set { lock.withLockVoid { _value = newValue } }
        }

        init(_ value: Element) {
            _value = value
        }
    }
    private let continuation: AsyncThrowingStream<Element, any Error>.Continuation
    private let streamIterator:
        () -> AsyncBroadcastSequence<AsyncThrowingStream<Element, any Error>>.AsyncIterator
    private let state: State

    /// The current value of the subject. This property is thread-safe.
    /// Updating this property will also broadcast the new value to all active consumers.
    public var value: Element {
        get { state.value }
        set {
            state.value = newValue
            continuation.yield(newValue)
        }
    }

    /// Creates a `CurrentValueSubject` with an initial value.
    /// - Parameter value: The initial value that will be broadcast to consumers.
    public init(_ value: Element) {
        let (s, c) = AsyncThrowingStream<Element, any Error>.makeStream()
        continuation = c
        let shared = s.share()
        streamIterator = { shared.makeAsyncIterator() }
        state = State(value)
    }

    /// Creates a `CurrentValueSubject` with an initial `Void` value.
    public convenience init() where Element == Void {
        self.init(())
    }

    public struct Iterator: AsyncIteratorProtocol, @unchecked Sendable {
        var upstream: AsyncBroadcastSequence<AsyncThrowingStream<Element, any Error>>.AsyncIterator
        let finished: Result<Element?, any Error>?
        let state: State
        private var sentCurrentValue = false

        init(
            upstream: AsyncBroadcastSequence<AsyncThrowingStream<Element, any Error>>.AsyncIterator,
            state: State
        ) {
            self.upstream = upstream
            self.finished = state.finishedResult
            self.state = state
        }

        public mutating func next() async throws -> Element? {
            guard finished == nil else { return try finished?.get() }
            guard sentCurrentValue == false else {
                return try await upstream.next()
            }
            sentCurrentValue = true
            return state.value
        }
    }

    public func makeAsyncIterator() -> Iterator {
        .init(upstream: streamIterator(), state: state)
    }

    /// Sends a new value to all current and future consumers.
    /// - Parameter element: The new value to broadcast.
    public func send(_ element: Element) {
        guard state.finishedResult == nil else { return }
        value = element
    }

    /// Sends a value to consumers when the subject's `Element` is `Void`.
    /// This is useful for signaling purposes rather than data transmission.
    public func send() where Element == Void {
        guard state.finishedResult == nil else { return }
        value = ()
    }

    /// Completes the subject, preventing any further values from being sent.
    /// Once completed, all current consumers will receive the completion, and no further values can be emitted.
    /// - Parameter completion: The completion event, either `.finished` or `.failure(Error)`.
    public func send(completion: Completion<any Error>) {
        guard state.finishedResult == nil else { return }
        switch completion {
            case .finished:
                defer { state.finishedResult = .success(nil) }
                continuation.finish()
            case .failure(let error):
                defer { state.finishedResult = .failure(error) }
                continuation.finish(throwing: error)
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

