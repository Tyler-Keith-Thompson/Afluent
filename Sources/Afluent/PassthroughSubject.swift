//
//  PassthroughSubject.swift
//  Afluent
//
//  Created by Tyler Thompson on 10/12/24.
//

/// A subject that broadcasts values to multiple consumers without storing a current value.
/// Unlike `CurrentValueSubject`, `PassthroughSubject` does not retain the most recent value.
/// It only sends values as they are emitted, meaning consumers will only receive values that are sent after they start listening.
/// This is an `AsyncSequence` that allows multiple tasks to asynchronously consume values and mimics Combine's PassthroughSubject.
public final class PassthroughSubject<Element: Sendable>: AsyncSequence, @unchecked Sendable {
    private class State: @unchecked Sendable {
        private let lock = Lock.allocate()
        private var _finishedResult: Result<Element?, any Error>?
        var finishedResult: Result<Element?, any Error>? {
            get { lock.withLock { _finishedResult } }
            set { lock.withLockVoid { _finishedResult = newValue } }
        }
    }
    private let continuation: AsyncThrowingStream<Element, any Error>.Continuation
    private let streamIterator:
        () -> AsyncBroadcastSequence<AsyncThrowingStream<Element, any Error>>.AsyncIterator
    private let state = State()

    /// Creates a `PassthroughSubject`.
    public init() {
        let (s, c) = AsyncThrowingStream<Element, any Error>.makeStream()
        continuation = c
        let shared = s.share()
        streamIterator = { shared.makeAsyncIterator() }
    }

    public struct Iterator: AsyncIteratorProtocol, @unchecked Sendable {
        var upstream: AsyncBroadcastSequence<AsyncThrowingStream<Element, any Error>>.AsyncIterator
        let finished: Result<Element?, any Error>?

        public mutating func next() async throws -> Element? {
            guard finished == nil else { return try finished?.get() }
            return try await upstream.next()
        }
    }

    public func makeAsyncIterator() -> Iterator {
        .init(upstream: streamIterator(), finished: state.finishedResult)
    }

    /// Sends a new value to all current and future consumers.
    /// - Parameter element: The new value to broadcast.
    public func send(_ element: Element) {
        guard state.finishedResult == nil else { return }
        continuation.yield(element)
    }

    /// Sends a value to consumers when the subject's `Element` is `Void`.
    /// This is useful for signaling purposes rather than data transmission.
    public func send() where Element == Void {
        guard state.finishedResult == nil else { return }
        continuation.yield()
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

extension PassthroughSubject {
    /// Represents the completion event of a subject, which can either succeed or fail with an error.
    public enum Completion<Failure: Error> {
        case finished
        case failure(Failure)
    }
}
