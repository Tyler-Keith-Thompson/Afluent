//
//  SubjectBroadcaster.swift
//  Afluent
//

/// The shared engine behind `PassthroughSubject` and `CurrentValueSubject`.
///
/// A consumer subscribes when its iterator is created and gets its own buffer from then on, so a slow consumer
/// still sees every value in order. A value sent with no subscribers is dropped. When the broadcaster tracks a
/// current value, a new subscriber's buffer starts with that value, set in the same critical region that registers
/// it, so the subscriber sees exactly the current value followed by later sends.
final class SubjectBroadcaster<Element: Sendable>: Sendable {
    fileprivate struct Subscriber: Sendable {
        var buffer = FIFOQueue<Element>()
        var terminal: Result<Element?, any Error>?
        var continuation: UnsafeContinuation<Result<Element?, any Error>, Never>?
        /// The token of the ``SubjectSubscription`` wait that registered `continuation`, so that a cancellation
        /// handler resumes only its own wait; `nil` for an iterator's wait.
        var waitToken: Int?

        mutating func drain() {
            guard let continuation else { return }
            if let element = buffer.popFirst() {
                self.continuation = nil
                waitToken = nil
                continuation.resume(returning: .success(element))
            } else if let terminal {
                self.continuation = nil
                waitToken = nil
                // A failure is delivered once; afterwards the subscriber is simply finished.
                self.terminal = .success(nil)
                continuation.resume(returning: terminal)
            }
        }
    }

    fileprivate struct State: Sendable {
        var nextID = 0
        var nextWaitToken = 0
        var subscribers = [Int: Subscriber]()
        var finishedResult: Result<Element?, any Error>?
        /// `nil` when the broadcaster does not track a current value (`PassthroughSubject`).
        var current: Element?

        mutating func emit(_ update: (inout Subscriber) -> Void) {
            // Iterate a snapshot: a live `keys` view keeps the dictionary storage shared, so the first mutation
            // would copy the dictionary and then every subscriber's buffer on append.
            for id in Array(subscribers.keys) {
                update(&subscribers[id]!)
                subscribers[id]!.drain()
            }
        }
    }

    private let state: CriticalState<State>

    /// - Parameter current: The initial current value, or `nil` to not track one.
    init(current: Element? = nil) {
        var initial = State()
        initial.current = current
        state = CriticalState(initial)
    }

    /// The current value. Only meaningful when the broadcaster was created with one.
    var current: Element? {
        state.withCriticalRegion { $0.current }
    }

    /// - Parameter keepsPlaceOnCancel: `false` for an iterator, whose cancelled `next()` ends the subscription;
    ///   `true` for a ``SubjectSubscription``, whose cancelled `next()` throws and keeps the subscriber and its buffer.
    func subscribe(keepsPlaceOnCancel: Bool = false) -> Subscription {
        Subscription(state: state, keepsPlaceOnCancel: keepsPlaceOnCancel)
    }

    /// Updates the current value (if tracked) and sends it to every subscriber. Does nothing once finished.
    func send(_ element: Element) {
        state.withCriticalRegion { state in
            guard state.finishedResult == nil else { return }
            if state.current != nil { state.current = element }
            state.emit { $0.buffer.append(element) }
        }
    }

    /// Updates the current value even after completion, and sends it to subscribers if not yet finished.
    func setCurrent(_ element: Element) {
        state.withCriticalRegion { state in
            state.current = element
            guard state.finishedResult == nil else { return }
            state.emit { $0.buffer.append(element) }
        }
    }

    /// Finishes every subscriber after its buffered values. Later subscribers receive `result` immediately.
    func finish(_ result: Result<Element?, any Error>) {
        state.withCriticalRegion { state in
            guard state.finishedResult == nil else { return }
            state.finishedResult = result
            state.emit { $0.terminal = result }
        }
    }

    final class Subscription: Sendable {
        private let state: CriticalState<State>
        private let id: Int?
        private let finished: Result<Element?, any Error>?
        private let keepsPlaceOnCancel: Bool

        fileprivate init(state: CriticalState<State>, keepsPlaceOnCancel: Bool) {
            self.state = state
            self.keepsPlaceOnCancel = keepsPlaceOnCancel
            (id, finished) = state.withCriticalRegion { state in
                if let finished = state.finishedResult {
                    return (nil, finished)
                }
                defer { state.nextID += 1 }
                var subscriber = Subscriber()
                if let current = state.current { subscriber.buffer.append(current) }
                state.subscribers[state.nextID] = subscriber
                return (state.nextID, nil)
            }
        }

        deinit {
            guard let id else { return }
            _ = state.withCriticalRegion { $0.subscribers.removeValue(forKey: id) }
        }

        func next() async throws -> Element? {
            guard let id else { return try finished?.get() }
            if keepsPlaceOnCancel { return try await nextKeepingPlace(id: id) }
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

        /// Waits for the next value; a cancelled wait throws `CancellationError` and leaves the subscriber, with
        /// everything buffered for it, in place for the next call. A call made while another is waiting throws
        /// `SubjectSubscription.ConcurrentNext` and leaves that wait and the buffer as they were.
        private func nextKeepingPlace(id: Int) async throws -> Element? {
            // One critical region settles every call that needn't wait. The rest take a token here, before the
            // cancellation handler is installed, because that handler can run before the continuation exists.
            let token: Int
            switch state.withCriticalRegion({ $0.beginWait(id: id) }) {
                case .settled(let result): return try result.get()
                case .wait(let waitToken): token = waitToken
            }
            let result = await withTaskCancellationHandler { [state] in
                await withUnsafeContinuation {
                    (continuation: UnsafeContinuation<Result<Element?, any Error>, Never>) in
                    state.withCriticalRegion { state in
                        // Checked again under the lock: a cancellation handler that ran before this registration
                        // found no continuation to resume, and the task's cancelled flag is set before its handlers
                        // run, so it is seen here.
                        guard !Task.isCancelled else {
                            continuation.resume(returning: .failure(CancellationError()))
                            return
                        }
                        guard state.subscribers[id] != nil else {
                            continuation.resume(returning: .success(nil))
                            return
                        }
                        // Another call registered since this one took its token. Replacing its continuation would
                        // leave it waiting for ever, so this call is the one turned away.
                        guard state.subscribers[id]!.continuation == nil else {
                            continuation.resume(returning: .failure(SubjectSubscription<Element>.ConcurrentNext()))
                            return
                        }
                        state.subscribers[id]!.continuation = continuation
                        state.subscribers[id]!.waitToken = token
                        state.subscribers[id]!.drain()
                    }
                }
            } onCancel: { [state] in
                let continuation: UnsafeContinuation<Result<Element?, any Error>, Never>? =
                    state.withCriticalRegion { state in
                        // Only this call's own wait: a call turned away must not cancel the one that is waiting.
                        guard state.subscribers[id]?.waitToken == token,
                            let continuation = state.subscribers[id]?.continuation
                        else { return nil }
                        state.subscribers[id]!.continuation = nil
                        state.subscribers[id]!.waitToken = nil
                        return continuation
                    }
                continuation?.resume(returning: .failure(CancellationError()))
            }
            return try result.get()
        }
    }
}

/// How a ``SubjectSubscription`` wait begins: settled at once, or waiting under a token.
private enum WaitStart<Element: Sendable> {
    case settled(Result<Element?, any Error>)
    case wait(token: Int)
}

extension SubjectBroadcaster.State {
    /// Settles a ``SubjectSubscription`` call that needn't wait (cancelled, unsubscribed, another call waiting, or a
    /// value or the end already buffered), or hands it a token to wait under.
    fileprivate mutating func beginWait(id: Int) -> WaitStart<Element> {
        guard !Task.isCancelled else { return .settled(.failure(CancellationError())) }
        guard subscribers[id] != nil else { return .settled(.success(nil)) }
        guard subscribers[id]!.continuation == nil else {
            return .settled(.failure(SubjectSubscription<Element>.ConcurrentNext()))
        }
        if let element = subscribers[id]!.buffer.popFirst() { return .settled(.success(element)) }
        if let terminal = subscribers[id]!.terminal {
            // A failure is delivered once; afterwards the subscriber is simply finished.
            subscribers[id]!.terminal = .success(nil)
            return .settled(terminal)
        }
        // Wrapping: a token only has to differ from the one wait that can be registered alongside it.
        defer { nextWaitToken &+= 1 }
        return .wait(token: nextWaitToken)
    }
}
