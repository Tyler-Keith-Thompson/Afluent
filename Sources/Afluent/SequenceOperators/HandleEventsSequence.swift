//
//  HandleEventsSequence.swift
//
//
//  Created by Tyler Thompson on 12/1/23.
//

import Foundation

extension AsyncSequences {
    public struct HandleEvents<Upstream: AsyncSequence>: AsyncSequence {
        public typealias Element = Upstream.Element
        let upstream: Upstream
        let receiveOutput: ((Element) async throws -> Void)?
        let receiveError: ((Error) async throws -> Void)?
        let receiveComplete: (() async throws -> Void)?
        let receiveCancel: (() async throws -> Void)?

        public struct AsyncIterator: AsyncIteratorProtocol {
            let upstream: Upstream
            let receiveOutput: ((Element) async throws -> Void)?
            let receiveError: ((Error) async throws -> Void)?
            let receiveComplete: (() async throws -> Void)?
            let receiveCancel: (() async throws -> Void)?
            lazy var iterator = upstream.makeAsyncIterator()

            public mutating func next() async throws -> Element? {
                do {
                    try Task.checkCancellation()
                    if let val = try await iterator.next() {
                        try await receiveOutput?(val)
                        return val
                    } else {
                        return nil
                    }
                } catch {
                    if !(error is CancellationError) {
                        try await receiveError?(error)
                    } else {
                        try await receiveCancel?()
                    }
                    throw error
                }
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(upstream: upstream,
                          receiveOutput: receiveOutput,
                          receiveError: receiveError,
                          receiveComplete: receiveComplete,
                          receiveCancel: receiveCancel)
        }
    }
}

extension AsyncSequence {
    /// Adds side-effects to the receiving events of the upstream `AsyncSequence`.
    ///
    /// - Parameters:
    ///   - receiveOutput: A closure that is invoked when the upstream emits a successful output. The closure can throw errors.
    ///   - receiveError: A closure that is invoked when the upstream emits an error. The closure can throw errors.
    ///   - receiveCancel: A closure that is invoked when the unit of work is cancelled. The closure can throw errors.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that performs the side-effects for the specified receiving events.
    ///
    /// - Note: The returned `AsynchronousUnitOfWork` forwards all receiving events from the upstream unit of work.
    public func handleEvents(@_inheritActorContext @_implicitSelfCapture receiveOutput: ((Element) async throws -> Void)? = nil, @_inheritActorContext @_implicitSelfCapture receiveError: ((Error) async throws -> Void)? = nil, @_inheritActorContext @_implicitSelfCapture receiveComplete: (() async throws -> Void)? = nil, @_inheritActorContext @_implicitSelfCapture receiveCancel: (() async throws -> Void)? = nil) -> AsyncSequences.HandleEvents<Self> {
        AsyncSequences.HandleEvents(upstream: self, receiveOutput: receiveOutput, receiveError: receiveError, receiveComplete: receiveComplete, receiveCancel: receiveCancel)
    }
}
