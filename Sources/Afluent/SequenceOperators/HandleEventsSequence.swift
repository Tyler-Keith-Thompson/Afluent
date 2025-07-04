//
//  HandleEventsSequence.swift
//
//
//  Created by Tyler Thompson on 12/1/23.
//

import Foundation

extension AsyncSequences {
    /// Used as the implementation detail for the ``AsyncSequence/handleEvents(receiveMakeIterator:receiveNext:receiveOutput:receiveError:receiveComplete:receiveCancel:)`` operator.
    public struct HandleEvents<Upstream: AsyncSequence & Sendable>: AsyncSequence, Sendable {
        public typealias Element = Upstream.Element
        let upstream: Upstream
        let receiveMakeIterator: (@Sendable () -> Void)?
        let receiveNext: (@Sendable () async throws -> Void)?
        let receiveOutput: (@Sendable (Element) async throws -> Void)?
        let receiveError: (@Sendable (Error) async throws -> Void)?
        let receiveComplete: (@Sendable () async throws -> Void)?
        let receiveCancel: (@Sendable () async throws -> Void)?

        public struct AsyncIterator: AsyncIteratorProtocol {
            var upstream: Upstream.AsyncIterator
            let receiveNext: (() async throws -> Void)?
            let receiveOutput: ((Element) async throws -> Void)?
            let receiveError: ((Error) async throws -> Void)?
            let receiveComplete: (() async throws -> Void)?
            let receiveCancel: (() async throws -> Void)?

            public mutating func next() async throws -> Element? {
                do {
                    try Task.checkCancellation()
                    try await receiveNext?()
                    if let val = try await upstream.next() {
                        try await receiveOutput?(val)
                        return val
                    } else {
                        try await receiveComplete?()
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
            receiveMakeIterator?()
            return AsyncIterator(
                upstream: upstream.makeAsyncIterator(),
                receiveNext: receiveNext,
                receiveOutput: receiveOutput,
                receiveError: receiveError,
                receiveComplete: receiveComplete,
                receiveCancel: receiveCancel)
        }
    }
}

extension AsyncSequence where Self: Sendable {
    /// Adds side-effects to the lifetime events of the sequence.
    ///
    /// Use this to observe or act on events like output, error, completion, or cancellation.
    ///
    /// ## Example
    /// ```
    /// for try await value in Just(1).handleEvents(receiveOutput: { print("Saw value: \($0)") }) {
    ///     print("Received: \(value)")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - receiveMakeIterator: A closure that is invoked when an iterator is requested from this sequence.
    ///   - receiveNext: A closure that is invoked when the next element is requested from this sequence. The closure can throw errors.
    ///   - receiveOutput: A closure that is invoked when the upstream emits a successful output. The closure can throw errors.
    ///   - receiveError: A closure that is invoked when the upstream emits an error. The closure can throw errors.
    ///   - receiveComplete: A closure that is invoked when the upstream completes. The closure can throw errors.
    ///   - receiveCancel: A closure that is invoked when the sequence is cancelled. The closure can throw errors.
    ///
    /// - Returns: An async sequence that performs the side-effects for the specified events.
    ///
    /// - Note: The returned sequence forwards all events from the upstream.
    public func handleEvents(
        @_implicitSelfCapture receiveMakeIterator: (@Sendable () -> Void)? = nil,
        @_inheritActorContext @_implicitSelfCapture receiveNext: (
            @Sendable () async throws -> Void
        )? = nil,
        @_inheritActorContext @_implicitSelfCapture receiveOutput: (
            @Sendable (Element) async throws -> Void
        )? = nil,
        @_inheritActorContext @_implicitSelfCapture receiveError: (
            @Sendable (Error) async throws -> Void
        )? = nil,
        @_inheritActorContext @_implicitSelfCapture receiveComplete: (
            @Sendable () async throws -> Void
        )? = nil,
        @_inheritActorContext @_implicitSelfCapture receiveCancel: (
            @Sendable () async throws -> Void
        )? = nil
    ) -> AsyncSequences.HandleEvents<Self> {
        AsyncSequences.HandleEvents(
            upstream: self, receiveMakeIterator: receiveMakeIterator, receiveNext: receiveNext,
            receiveOutput: receiveOutput, receiveError: receiveError,
            receiveComplete: receiveComplete, receiveCancel: receiveCancel)
    }
}

