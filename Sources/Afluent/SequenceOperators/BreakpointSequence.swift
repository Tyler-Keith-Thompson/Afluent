//
//  BreakpointSequence.swift
//
//
//  Created by Tyler Thompson on 12/10/23.
//

import Foundation

extension AsyncSequence where Self: Sendable {
    /// Introduces a conditional breakpoint into the async sequence.
    ///
    /// Use this to pause execution in a debugger when a specified output or error condition is met.
    /// If the provided closure returns `true`, a `SIGTRAP` signal is raised.
    ///
    /// - Parameters:
    ///   - receiveOutput: Closure called with each output. Return `true` to trigger a breakpoint. Default is `nil`.
    ///   - receiveError: Closure called with each error. Return `true` to trigger a breakpoint. Default is `nil`.
    ///
    /// ## Example
    /// ```swift
    /// let numbers = AsyncStream<Int> { continuation in
    ///     continuation.yield(1)
    ///     continuation.yield(42)
    ///     continuation.finish()
    /// }
    /// for try await value in numbers.breakpoint(receiveOutput: { $0 == 42 }) {
    ///     print(value)
    /// }
    /// ```
    @_transparent @_alwaysEmitIntoClient @inlinable public func breakpoint(
        receiveOutput: (@Sendable (Element) async throws -> Bool)? = nil,
        receiveError: (@Sendable (Error) async throws -> Bool)? = nil
    ) -> AsyncSequences.HandleEvents<Self> {
        handleEvents(
            receiveOutput: { output in
                if try await receiveOutput?(output) == true {
                    raise(SIGTRAP)
                }
            },
            receiveError: { error in
                if try await receiveError?(error) == true {
                    raise(SIGTRAP)
                }
            })
    }

    /// Introduces a breakpoint into the async sequence when an error occurs.
    ///
    /// ## Example
    /// ```swift
    /// let stream = AsyncStream<Int> { continuation in
    ///     continuation.finish(throwing: MyError())
    /// }
    /// for try await value in stream.breakpointOnError() {
    ///     print(value)
    /// }
    /// ```
    @_transparent @_alwaysEmitIntoClient @inlinable public func breakpointOnError()
        -> AsyncSequences.HandleEvents<Self>
    {
        breakpoint(receiveError: { _ in true })
    }
}
