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

    func subscribe() -> Subscription {
        Subscription(state: state)
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

        fileprivate init(state: CriticalState<State>) {
            self.state = state
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
