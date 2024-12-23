//
//  SingleValueSubject.swift
//
//
//  Created by Tyler Thompson on 11/10/23.
//

import Foundation

/// A subject that emits a single value or an error.
///
/// `SingleValueSubject` is an `AsynchronousUnitOfWork` that can be manually completed with either a success value or an error. It's useful for scenarios where you need to bridge callback-based APIs into the world of `async/await`.
///
/// - Note: Once completed, any further attempts to send a value or an error will result in a `SubjectError.alreadyCompleted`.
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
        switch subjectState {
            case .sentValue, .sentError: return true
            case .noValue, .hasContinuation: return false
        }
    }
    private var subjectState = State.noValue

    /// Creates a new `SingleValueSubject`.
    public init() {}

    public func _operation() async throws -> AsynchronousOperation<Success> {
        AsynchronousOperation { [weak self] in
            guard let self else { throw CancellationError() }

            func getSentValue() throws -> Success? {
                try self._lock.protect {
                    if case .sentValue(let success) = self.subjectState {
                        return success
                    } else if case .sentError(let error) = self.subjectState {
                        throw error
                    }
                    return nil
                }
            }

            if let success = try getSentValue() { return success }

            return try await withUnsafeThrowingContinuation { [weak self] continuation in
                guard let self else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                self.lock()
                do {
                    if let success = try getSentValue() {
                        self.unlock()
                        continuation.resume(returning: success)
                        return
                    }
                } catch {
                    self.unlock()
                    continuation.resume(throwing: error)
                    return
                }
                self.subjectState = .hasContinuation(continuation)
                self.unlock()
            }
        }
    }

    private func lock() { _lock.lock() }
    private func unlock() { _lock.unlock() }

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
                    throw SubjectError.alreadyCompleted
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
                    throw SubjectError.alreadyCompleted
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
                    throw SubjectError.alreadyCompleted
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
