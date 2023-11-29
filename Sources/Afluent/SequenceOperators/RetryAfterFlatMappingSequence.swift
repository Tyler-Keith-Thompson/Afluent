//
//  RetryAfterFlatMappingSequence.swift
//
//
//  Created by Tyler Thompson on 11/28/23.
//

import Foundation
extension AsyncSequences {
    public final class RetryAfterFlatMapping<Upstream: AsyncSequence, Downstream: AsyncSequence>: AsyncSequence, AsyncIteratorProtocol where Upstream.Element == Downstream.Element {
        public typealias Element = Upstream.Element
        private let lock = NSRecursiveLock()
        let upstream: Upstream
        var retries: UInt
        
        let transform: @Sendable (Error) async throws -> Downstream
        lazy var iterator = upstream.makeAsyncIterator()
        
        init(upstream: Upstream, retries: UInt, transform: @escaping @Sendable (Error) async throws -> Downstream) {
            self.upstream = upstream
            self.retries = retries
            self.transform = transform
        }
        
        private func _lock() { lock.lock() }
        private func _unlock() { lock.unlock() }

        public func next() async throws -> Upstream.Element? {
            do {
                try Task.checkCancellation()
                _lock()
                var i = iterator
                _unlock()
                return try await i.next()
            } catch {
                guard !(error is CancellationError) else { throw error }

                _lock()
                if retries > 0 {
                    retries -= 1
                    iterator = upstream.makeAsyncIterator()
                    for try await _ in try await transform(error) { }
                    _unlock()
                    return try await next()
                } else {
                    _unlock()
                    throw error
                }
            }
        }
        
        public func makeAsyncIterator() -> RetryAfterFlatMapping<Upstream, Downstream> { self }
    }
    
    public final class RetryOnAfterFlatMapping<Upstream: AsyncSequence, Failure: Error & Equatable, Downstream: AsyncSequence>: AsyncSequence, AsyncIteratorProtocol where Upstream.Element == Downstream.Element {
        public typealias Element = Upstream.Element
        private let lock = NSRecursiveLock()
        let upstream: Upstream
        var retries: UInt
        let error: Failure
        let transform: @Sendable (Failure) async throws -> Downstream
        lazy var iterator = upstream.makeAsyncIterator()
        
        init(upstream: Upstream, retries: UInt, error: Failure, transform: @escaping @Sendable (Failure) async throws -> Downstream) {
            self.upstream = upstream
            self.retries = retries
            self.error = error
            self.transform = transform
        }
        
        private func _lock() { lock.lock() }
        private func _unlock() { lock.unlock() }

        public func next() async throws -> Upstream.Element? {
            do {
                try Task.checkCancellation()
                _lock()
                var i = iterator
                _unlock()
                return try await i.next()
            } catch(let err) {
                guard !(err is CancellationError) else { throw err }
                
                _lock()
                guard let unwrappedError = (err as? Failure),
                      unwrappedError == error else {
                    _unlock()
                    throw err
                }
                if retries > 0 {
                    retries -= 1
                    iterator = upstream.makeAsyncIterator()
                    _unlock()
                    for try await _ in try await transform(unwrappedError) { }
                    return try await next()
                } else {
                    _unlock()
                    throw error
                }
            }
        }
        
        public func makeAsyncIterator() -> RetryOnAfterFlatMapping<Upstream, Failure, Downstream> { self }
    }
}

extension AsyncSequence {
    /// Retries the upstream `AsyncSequence` up to a specified number of times while applying a transformation on error.
    ///
    /// - Parameters:
    ///   - retries: The maximum number of times to retry the upstream, defaulting to 1.
    ///   - transform: An async closure that takes the error from the upstream and returns a new `AsyncSequence`.
    ///
    /// - Returns: An `AsyncSequence` that emits the same output as the upstream but retries on failure up to the specified number of times, with the applied transformation.
    public func retry<D: AsyncSequence>(_ retries: UInt = 1, _ transform: @escaping @Sendable (Error) async throws -> D) -> AsyncSequences.RetryAfterFlatMapping<Self, D> {
        AsyncSequences.RetryAfterFlatMapping(upstream: self, retries: retries, transform: transform)
    }
    
    /// Retries the upstream `AsynchronousUnitOfWork` up to a specified number of times only when a specific error occurs, while applying a transformation on error.
    ///
    /// - Parameters:
    ///   - retries: The maximum number of times to retry the upstream, defaulting to 1.
    ///   - error: The specific error that should trigger a retry.
    ///   - transform: An async closure that takes the error from the upstream and returns a new `AsyncSequence`.
    ///
    /// - Returns: An `AsyncSequence` that emits the same output as the upstream but retries on the specified error up to the specified number of times, with the applied transformation.
    public func retry<D: AsyncSequence, E: Error & Equatable>(_ retries: UInt = 1, on error: E, _ transform: @escaping @Sendable (E) async throws -> D) -> AsyncSequences.RetryOnAfterFlatMapping<Self, E, D> {
        AsyncSequences.RetryOnAfterFlatMapping(upstream: self, retries: retries, error: error, transform: transform)
    }
}
