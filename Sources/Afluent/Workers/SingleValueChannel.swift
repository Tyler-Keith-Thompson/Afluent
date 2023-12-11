//
//  SingleValueChannel.swift
//
//
//  Created by Tyler Thompson on 11/11/23.
//

import Foundation

/// A channel that emits a single value or an error.
///
/// ` SingleValueChannel` is an `AsynchronousUnitOfWork` that can be manually completed with either a success value or an error. It's useful for scenarios where you need to bridge callback-based APIs into the world of `async/await`.
///
/// - Note: Once completed, any further attempts to send a value or an error will result in a `ChannelError.alreadyCompleted`.
/// - Important: This is very similar to a `SingleValueSubject`, but shares more similarities with `AsyncChannel` in swift-async-algorithms. Sending is an `async` operation, and therefore the ergonomics of this type are a little different. However, it should generally be preferred where possible over `SingleValueSubject`
public actor SingleValueChannel<Success: Sendable>: AsynchronousUnitOfWork {
    /// Errors specific to `SingleValueChannel`.
    public enum ChannelError: Error {
        /// Indicates that the channel has already been completed and cannot accept further values or errors.
        case alreadyCompleted
    }

    public let state = TaskState<Success>()
    private var channelState = State.noValue

    /// Creates a new `SingleValueChannel`.
    public init() { }

    public func _operation() async throws -> AsynchronousOperation<Success> {
        AsynchronousOperation { [weak self] in
            guard let self else { throw CancellationError() }
            if case .sentValue(let success) = await self.channelState {
                return success
            } else if case .sentError(let error) = await self.channelState {
                throw error
            }

            return try await withUnsafeThrowingContinuation { continuation in
                Task { [weak self] in
                    guard let self else { throw CancellationError() }
                    await self.setchannelState(.hasContinuation(continuation))
                }
            }
        }
    }

    private func setchannelState(_ state: State) {
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
            case .noValue: channelState = .sentValue(value)
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
    public func send() throws where Success == Void {
        switch channelState {
            case .noValue: channelState = .sentValue(())
            case .hasContinuation(let continuation):
                channelState = .sentValue(())
                continuation.resume(returning: ())
            default:
                throw ChannelError.alreadyCompleted
        }
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
