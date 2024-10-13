//
//  CurrentValueSubject.swift
//  Afluent
//
//  Created by Tyler Thompson on 10/12/24.
//

@_spi(Experimental) public final class CurrentValueSubject<Element: Sendable>: AsyncSequence, @unchecked Sendable {
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
    private let streamIterator: () -> AsyncBroadcastSequence<AsyncThrowingStream<Element, any Error>>.AsyncIterator
    private let state: State
    
    public var value: Element {
        get { state.value }
        set { state.value = newValue; continuation.yield(newValue) }
    }
    
    public init(_ value: Element) {
        let (s, c) = AsyncThrowingStream<Element, any Error>.makeStream()
        continuation = c
        let shared = s.share()
        streamIterator = { shared.makeAsyncIterator() }
        state = State(value)
    }

    public convenience init() where Element == Void {
        self.init(())
    }

    public struct Iterator: AsyncIteratorProtocol, @unchecked Sendable {
        var upstream: AsyncBroadcastSequence<AsyncThrowingStream<Element, any Error>>.AsyncIterator
        let finished: Result<Element?, any Error>?
        let state: State
        private var sentCurrentValue = false

        init(upstream: AsyncBroadcastSequence<AsyncThrowingStream<Element, any Error>>.AsyncIterator, state: State) {
            self.upstream = upstream
            self.finished = state.finishedResult
            self.state = state
        }
                
        public mutating func next() async throws -> Element? {
            guard finished == nil else { return try finished?.get() }
            guard sentCurrentValue else {
                defer { sentCurrentValue = true }
                return state.value
            }
            return try await upstream.next()
        }
    }
    
    public func makeAsyncIterator() -> Iterator {
        .init(upstream: streamIterator(), state: state)
    }
    
    public func send(_ element: Element) {
        guard state.finishedResult == nil else { return }
        value = element
    }
    
    public func send() where Element == Void {
        guard state.finishedResult == nil else { return }
        value = ()
    }
    
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

@_spi(Experimental) extension CurrentValueSubject {
    public enum Completion<Failure: Error> {
        case finished
        case failure(Failure)
    }
}
