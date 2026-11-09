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
public final class SingleValueSubject<Success: Sendable>: AsynchronousUnitOfWork, Sendable {
    /// Errors specific to `SingleValueSubject`.
    public enum SubjectError: Error {
        /// Indicates that the subject has already been completed and cannot accept further values or errors.
        case alreadyCompleted
    }

    public let state = TaskState<Success>()
    var alreadySent: Bool {
        subjectState.withCriticalRegion { $0.sentResult != nil }
    }
    private let subjectState = CriticalState(State.noValue)

    /// Creates a new `SingleValueSubject`.
    public init() {}

    public func _operation() async throws -> AsynchronousOperation<Success> {
        AsynchronousOperation { [weak self] in
            guard let self else { throw CancellationError() }

            // Fast path: the value is already here, so no continuation is needed.
            let alreadySent = self.subjectState.withCriticalRegion { $0.sentResult }
            if let alreadySent { return try alreadySent.get() }

            return try await withUnsafeThrowingContinuation { [weak self] continuation in
                guard let self else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                // One critical region either finds the result or adds the continuation to the waiters, so a
                // `send` between the fast path and here is never missed. The continuation is resumed after the
                // lock is released.
                let sent: Result<Success, any Error>? = self.subjectState.withCriticalRegion { subjectState in
                    switch subjectState {
                        case .sentValue(let value): return .success(value)
                        case .sentError(let error): return .failure(error)
                        case .noValue:
                            subjectState = .waiting([continuation])
                            return nil
                        case .waiting(var continuations):
                            // Released first, so the array is uniquely referenced and appends in place.
                            subjectState = .noValue
                            continuations.append(continuation)
                            subjectState = .waiting(continuations)
                            return nil
                    }
                }
                if let sent { continuation.resume(with: sent) }
            }
        }
    }

    public func cancel() {
        // custom implementation of cancel() required due to the need to finish the continuation
        state.cancel()
        try? self.send(error: CancellationError())
    }

    /// Sends a value to the subject.
    ///
    /// Completes the subject with the provided value, and every pending `execute()` returns it. If the subject is
    /// already completed, this method throws a `SubjectError.alreadyCompleted`.
    ///
    /// - Parameter value: The success value to send.
    /// - Throws: `SubjectError.alreadyCompleted` if the subject is already completed.
    /// - Complexity: O(*n*), where *n* is the number of pending `execute()` calls.
    public func send(_ value: Success) throws {
        if case .waiting(let waiters) = try complete(.sentValue(value)) {
            for waiter in waiters { waiter.resume(returning: value) }
        }
    }

    /// Sends a value to the subject.
    ///
    /// Completes the subject, and every pending `execute()` returns. If the subject is already completed, this method
    /// throws a `SubjectError.alreadyCompleted`.
    ///
    /// - Throws: `SubjectError.alreadyCompleted` if the subject is already completed.
    /// - Complexity: O(*n*), where *n* is the number of pending `execute()` calls.
    public func send() throws where Success == Void {
        if case .waiting(let waiters) = try complete(.sentValue(())) {
            for waiter in waiters { waiter.resume(returning: ()) }
        }
    }

    /// Sends an error to the subject.
    ///
    /// Completes the subject with the provided error, and every pending `execute()` throws it. If the subject is
    /// already completed, this method throws a `SubjectError.alreadyCompleted`.
    ///
    /// - Parameter error: The error to send.
    /// - Throws: `SubjectError.alreadyCompleted` if the subject is already completed.
    /// - Complexity: O(*n*), where *n* is the number of pending `execute()` calls.
    public func send(error: Error) throws {
        if case .waiting(let waiters) = try complete(.sentError(error)) {
            for waiter in waiters { waiter.resume(throwing: error) }
        }
    }

    /// Records the completed state under the lock and returns the state it replaced, so the caller resumes any
    /// waiters after the lock is released.
    private func complete(_ completed: State) throws -> State {
        try subjectState.withCriticalRegion { subjectState in
            let previous = subjectState
            switch previous {
                case .noValue, .waiting: subjectState = completed
                case .sentValue, .sentError:
                    if self.state.isCancelled == false {
                        throw SubjectError.alreadyCompleted
                    }
            }
            return previous
        }
    }
}

extension SingleValueSubject {
    private enum State {
        case noValue
        case waiting([UnsafeContinuation<Success, any Error>])
        case sentValue(Success)
        case sentError(any Error)

        /// The value or error the subject completed with, or `nil` if it hasn't completed.
        var sentResult: Result<Success, any Error>? {
            switch self {
                case .sentValue(let success): return .success(success)
                case .sentError(let error): return .failure(error)
                case .noValue, .waiting: return nil
            }
        }
    }
}
