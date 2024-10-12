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
    private let finishedSubject = SingleValueSubject<Void>()
    
    public init() {
        let (s, c) = AsyncThrowingStream<Element, any Error>.makeStream()
        continuation = c
        let shared = s.share()
        streamIterator = { shared.makeAsyncIterator() }
    }
    
    public class Iterator: AsyncIteratorProtocol, @unchecked Sendable {
        var upstream: AsyncBroadcastSequence<AsyncThrowingStream<Element, any Error>>.AsyncIterator
        let finished: @Sendable () async throws -> Void
        
        init(upstream: AsyncBroadcastSequence<AsyncThrowingStream<Element, any Error>>.AsyncIterator, finished: @Sendable @escaping () async throws -> Void) {
            self.upstream = upstream
            self.finished = finished
        }
        
        public func next() async throws -> Element? {
            return try await Race {
                try await finished()
                return nil
            } against: {
                try await self.upstream.next()
            }
        }
    }
    
    public func makeAsyncIterator() -> AsyncBroadcastSequence<AsyncThrowingStream<Element, any Error>>.AsyncIterator {
        streamIterator()
//        Iterator(upstream: streamIterator(), finished: { try await self.finishedSubject.execute() })
    }
    
    public func send(_ element: Element) {
        guard !finished.load(ordering: .sequentiallyConsistent) else { return }
        continuation.yield(element)
    }
    
    public func send() where Element == Void {
        
    }
    
    public func send(completion: Completion<any Error>) {
        defer {
            finished.store(true, ordering: .sequentiallyConsistent)
            try? finishedSubject.send()
        }
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
