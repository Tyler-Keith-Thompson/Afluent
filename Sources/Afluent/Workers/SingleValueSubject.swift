//
//  SingleValueSubject.swift
//
//
//  Created by Tyler Thompson on 11/10/23.
//

import Foundation

/// A subject for bridging callback-based APIs to async/await, emitting a single value or error.
///
/// `SingleValueSubject` is an `AsynchronousUnitOfWork` that you manually complete once, making it useful for integrating legacy, delegate, or callback-style APIs into modern async workflows.
///
/// ## Example: Bridging a delegate to async/await
/// ```swift
/// final class MyDelegate: NSObject, SomeLegacyDelegate {
///     let subject = SingleValueSubject<Data>()
///     func didReceive(data: Data) { try? subject.send(data) }
///     func didFail(error: Error) { try? subject.send(error: error) }
/// }
///
/// func fetchDataWithDelegate() async throws -> Data {
///     let delegate = MyDelegate()
///     startLegacyOperation(delegate: delegate)
///     return try await delegate.subject.execute()
/// }
/// ```
///
/// - Note: Once completed, any further send or error will throw `SubjectError.alreadyCompleted`.
/// - Important: This is conceptually similar to a Combine subject, but for async/await. Prefer `SingleValueChannel` for most bridging tasks—use this type when manual, thread-safe completion is required.
public final class SingleValueSubject<Success: Sendable>: AsynchronousUnitOfWork, @unchecked
    Sendable
{
    /// Errors specific to `SingleValueSubject`.
    public enum SubjectError: Error {
        /// Indicates that the subject has already been completed and cannot accept further values or errors.
        case alreadyCompleted
    }

    private let _lock = NSRecursiveLock()
    public let state = TaskState<Success>()
    var alreadySent: Bool {
        _lock.protect { sentResult != nil }
    }
    private var subjectState = State.noValue

    /// Creates a new `SingleValueSubject`.
    public init() {}

    public func _operation() async throws -> AsynchronousOperation<Success> {
        AsynchronousOperation { [weak self] in
            guard let self else { throw CancellationError() }

            // Fast path: the value is already here, so no continuation is needed.
            let alreadySent: Result<Success, any Error>? = self._lock.protect { self.sentResult }
            if let alreadySent { return try alreadySent.get() }

            return try await withUnsafeThrowingContinuation { [weak self] continuation in
                guard let self else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                // One critical region either finds the result or stores the continuation, so a `send` between
                // the fast path and here is never missed. The continuation is resumed after the lock is released.
                let sent: Result<Success, any Error>? = self._lock.protect {
                    if let sent = self.sentResult { return sent }
                    self.subjectState = .hasContinuation(continuation)
                    return nil
                }
                if let sent { continuation.resume(with: sent) }
            }
        }
    }

    /// The value or error the subject completed with, or `nil` if it hasn't completed. Read it inside `_lock`.
    private var sentResult: Result<Success, any Error>? {
        switch subjectState {
            case .sentValue(let success): return .success(success)
            case .sentError(let error): return .failure(error)
            case .noValue, .hasContinuation: return nil
        }
    }

    public func cancel() {
        // custom implementation of cancel() required due to the need to finish the continuation
        state.cancel()
        try? self.send(error: CancellationError())
    }

    /// Sends a value to the subject.
    ///
    /// Completes the subject with the provided value. If the subject is already completed, this method throws a `SubjectError.alreadyCompleted`.
    ///
    /// - Parameter value: The success value to send.
    /// - Throws: `SubjectError.alreadyCompleted` if the subject is already completed.
    public func send(_ value: Success) throws {
        try _lock.protect {
            switch self.subjectState {
                case .noValue: self.subjectState = .sentValue(value)
                case .hasContinuation(let continuation):
                    self.subjectState = .sentValue(value)
                    continuation.resume(returning: value)
                default:
                    if self.state.isCancelled == false {
                        throw SubjectError.alreadyCompleted
                    }
            }
        }
    }

    /// Sends a value to the subject.
    ///
    /// Completes the subject with the provided value. If the subject is already completed, this method throws a `SubjectError.alreadyCompleted`.
    ///
    /// - Throws: `SubjectError.alreadyCompleted` if the subject is already completed.
    public func send() throws where Success == Void {
        try _lock.protect {
            switch self.subjectState {
                case .noValue: self.subjectState = .sentValue(())
                case .hasContinuation(let continuation):
                    self.subjectState = .sentValue(())
                    continuation.resume(returning: ())
                default:
                    if self.state.isCancelled == false {
                        throw SubjectError.alreadyCompleted
                    }
            }
        }
    }

    /// Sends an error to the subject.
    ///
    /// Completes the subject with the provided error. If the subject is already completed, this method throws a `SubjectError.alreadyCompleted`.
    ///
    /// - Parameter error: The error to send.
    /// - Throws: `SubjectError.alreadyCompleted` if the subject is already completed.
    public func send(error: Error) throws {
        try _lock.protect {
            switch self.subjectState {
                case .noValue: self.subjectState = .sentError(error)
                case .hasContinuation(let continuation):
                    self.subjectState = .sentError(error)
                    continuation.resume(throwing: error)
                default:
                    if self.state.isCancelled == false {
                        throw SubjectError.alreadyCompleted
                    }
            }
        }
    }
}

extension SingleValueSubject {
    private enum State {
        case noValue
        case sentValue(Success)
        case sentError(Error)
        case hasContinuation(UnsafeContinuation<Success, Error>)
    }
}
