//
//  SingleValueChannel.swift
//
//
//  Created by Tyler Thompson on 11/11/23.
//

import Foundation

/// A channel for bridging callback-based APIs to async/await, emitting a single value or error.
///
/// `SingleValueChannel` is an `AsynchronousUnitOfWork` that can be manually completed exactly once, making it ideal for integrating legacy or delegate/callback APIs with modern async workflows.
///
/// ## Example: Bridging a callback to async/await
/// ```
/// func fetchData(url: URL) async throws -> Data {
///     let channel = SingleValueChannel<Data>()
///     let task = URLSession.shared.dataTask(with: url) { data, _, error in
///         if let data { try? await channel.send(data) }
///         else if let error { try? await channel.send(error: error) }
///     }
///     task.resume()
///     return try await channel.execute()
/// }
/// ```
///
/// - Note: Once completed, any further send or error will throw `ChannelError.alreadyCompleted`.
/// - Important: Prefer this over a subject for bridging when possible, as it is more ergonomic for async/await and similar to `AsyncChannel` in swift-async-algorithms.
public actor SingleValueChannel<Success: Sendable>: AsynchronousUnitOfWork {
    /// Errors specific to `SingleValueChannel`.
    public enum ChannelError: Error {
        /// Indicates that the channel has already been completed and cannot accept further values or errors.
        case alreadyCompleted
    }

    public let state = TaskState<Success>()
    private var channelState = State.noValue

    /// Creates a new `SingleValueChannel`.
    public init() {}

    public func _operation() async throws -> AsynchronousOperation<Success> {
        AsynchronousOperation { [weak self] in
            guard let self else { throw CancellationError() }

            return try await withUnsafeThrowingContinuation { continuation in
                Task {
                    await withTaskCancellationHandler { [weak self] in
                        guard let self else {
                            continuation.resume(throwing: CancellationError())
                            return
                        }
                        if case .sentValue(let success) = await self.channelState {
                            continuation.resume(returning: success)
                        } else if case .sentError(let error) = await self.channelState {
                            continuation.resume(throwing: error)
                        } else {
                            await self.setChannelState(.hasContinuation(continuation))
                        }
                    } onCancel: {
                        continuation.resume(throwing: CancellationError())
                    }
                }
            }
        }
    }

    private func setChannelState(_ state: State) {
        if case .hasContinuation(let continuation) = state {
            if case .sentValue(let val) = channelState {
                continuation.resume(returning: val)
                return
            } else if case .sentError(let error) = channelState {
                continuation.resume(throwing: error)
                return
            }
        }
        channelState = state
    }

    /// Sends a value to the channel.
    ///
    /// Completes the channel with the provided value. If the channel is already completed, this method throws a `ChannelError.alreadyCompleted`.
    ///
    /// - Parameter value: The success value to send.
    /// - Throws: `ChannelError.alreadyCompleted` if the channel is already completed.
    public func send(_ value: Success) throws {
        switch channelState {
            case .noValue:
                channelState = .sentValue(value)
            case .hasContinuation(let continuation):
                channelState = .sentValue(value)
                continuation.resume(returning: value)
            default:
                throw ChannelError.alreadyCompleted
        }
    }

    /// Sends a value to the channel.
    ///
    /// Completes the channel with the provided value. If the channel is already completed, this method throws a `ChannelError.alreadyCompleted`.
    ///
    /// - Throws: `ChannelError.alreadyCompleted` if the channel is already completed.
    @inlinable public func send() throws where Success == Void {
        try send(())
    }

    /// Sends an error to the channel.
    ///
    /// Completes the channel with the provided error. If the channel is already completed, this method throws a `ChannelError.alreadyCompleted`.
    ///
    /// - Parameter error: The error to send.
    /// - Throws: `ChannelError.alreadyCompleted` if the channel is already completed.
    public func send(error: Error) throws {
        switch channelState {
            case .noValue: channelState = .sentError(error)
            case .hasContinuation(let continuation):
                channelState = .sentError(error)
                continuation.resume(throwing: error)
            default:
                throw ChannelError.alreadyCompleted
        }
    }
}

extension SingleValueChannel {
    private enum State {
        case noValue
        case sentValue(Success)
        case sentError(Error)
        case hasContinuation(UnsafeContinuation<Success, Error>)
    }
}
