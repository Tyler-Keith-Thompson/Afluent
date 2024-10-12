//
//  PassthroughSubject.swift
//  Afluent
//
//  Created by Tyler Thompson on 10/12/24.
//

import Atomics

@_spi(Experimental) public final class PassthroughSubject<Element: Sendable>: AsyncSequence, @unchecked Sendable {
    private let continuation: AsyncThrowingStream<Element, any Error>.Continuation
    private let streamIterator: () -> AsyncBroadcastSequence<AsyncThrowingStream<Element, any Error>>.AsyncIterator
    private let finished: ManagedAtomic<Bool> = .init(false)
    
    public init() {
        let (s, c) = AsyncThrowingStream<Element, any Error>.makeStream()
        continuation = c
        let shared = s.share()
        streamIterator = { shared.makeAsyncIterator() }
    }
    
    public struct Iterator: AsyncIteratorProtocol, @unchecked Sendable {
        var upstream: AsyncBroadcastSequence<AsyncThrowingStream<Element, any Error>>.AsyncIterator
        let finished: Bool
        
        public mutating func next() async throws -> Element? {
            guard !finished else { return nil }
            return try await upstream.next()
        }
    }
    
    public func makeAsyncIterator() -> Iterator {
        .init(upstream: streamIterator(), finished: finished.load(ordering: .sequentiallyConsistent))
//        streamIterator()
    }
    
    public func send(_ element: Element) {
        guard !finished.load(ordering: .sequentiallyConsistent) else { return }
        continuation.yield(element)
    }
    
    public func send() where Element == Void {
        
    }
    
    public func send(completion: Completion<any Error>) {
        defer { finished.store(true, ordering: .sequentiallyConsistent) }
        switch completion {
        case .finished: continuation.finish()
        case .failure(let error): break
        }
    }
}

@_spi(Experimental) extension PassthroughSubject {
    public enum Completion<Failure: Error> {
        case finished
        case failure(Failure)
    }
}
