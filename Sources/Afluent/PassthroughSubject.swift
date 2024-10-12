//
//  PassthroughSubject.swift
//  Afluent
//
//  Created by Tyler Thompson on 10/12/24.
//

import Atomics

@_spi(Experimental) public final class PassthroughSubject<Element: Sendable>: AsyncSequence, @unchecked Sendable {
    private class State: @unchecked Sendable {
        private let lock = Lock.allocate()
        private var _finishedResult: Result<Element?, any Error>?
        var finishedResult: Result<Element?, any Error>? {
            get { lock.withLock { _finishedResult } }
            set { lock.withLockVoid { _finishedResult = newValue } }
        }
    }
    private let continuation: AsyncThrowingStream<Element, any Error>.Continuation
    private let streamIterator: () -> AsyncBroadcastSequence<AsyncThrowingStream<Element, any Error>>.AsyncIterator
    private let state = State()
    private let finished: ManagedAtomic<Bool> = .init(false)
    
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
    
    public func send(_ element: Element) {
        guard state.finishedResult == nil else { return }
        continuation.yield(element)
    }
    
    public func send() where Element == Void {
        guard state.finishedResult == nil else { return }
        continuation.yield()
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

@_spi(Experimental) extension PassthroughSubject {
    public enum Completion<Failure: Error> {
        case finished
        case failure(Failure)
    }
}
