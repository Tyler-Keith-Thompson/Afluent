//
//  Retry.swift
//  
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation

extension Workers {
    actor Retry<Success>: AsynchronousUnitOfWork {
        var retryCount: UInt

        let state: TaskState<Success>

        init<U: AsynchronousUnitOfWork>(upstream: U, retries: UInt) where U.Success == Success {
            retryCount = retries
            guard retries > 0 else {
                state = upstream.state
                return
            }
            state = TaskState<Success>.unsafeCreation()
            state.setOperation { [weak self] in
                guard let self else { throw CancellationError() }
                while await retryCount > 0 {
                    do {
                        return try await upstream.operation()
                    } catch {
                        await decrementRetry()
                        continue
                    }
                }
                return try await upstream.operation()
            }
        }
        
        func decrementRetry() {
            guard retryCount > 0 else { return }
            retryCount -= 1
        }
    }
    
    actor RetryOn<Success>: AsynchronousUnitOfWork {
        var retryCount: UInt

        let state: TaskState<Success>

        init<U: AsynchronousUnitOfWork, E: Error & Equatable>(upstream: U, retries: UInt, error: E) where U.Success == Success {
            retryCount = retries
            guard retries > 0 else {
                state = upstream.state
                return
            }
            state = TaskState<Success>.unsafeCreation()
            state.setOperation { [weak self] in
                guard let self else { throw CancellationError() }
                while await retryCount > 0 {
                    do {
                        return try await upstream.operation()
                    } catch(let err) {
                        guard let unwrappedError = (err as? E),
                              unwrappedError == error else { throw err }
                        await decrementRetry()
                        continue
                    }
                }
                return try await upstream.operation()
            }
        }
        
        func decrementRetry() {
            guard retryCount > 0 else { return }
            retryCount -= 1
        }
    }
}

extension AsynchronousUnitOfWork {
    /// Retries the upstream `AsynchronousUnitOfWork` up to a specified number of times.
    ///
    /// - Parameter retries: The maximum number of times to retry the upstream, defaulting to 1.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that emits the same output as the upstream but retries on failure up to the specified number of times.
    public func retry(_ retries: UInt = 1) -> some AsynchronousUnitOfWork<Success> {
        Workers.Retry(upstream: self, retries: retries)
    }
    
    /// Retries the upstream `AsynchronousUnitOfWork` up to a specified number of times only when a specific error occurs.
    ///
    /// - Parameters:
    ///   - retries: The maximum number of times to retry the upstream, defaulting to 1.
    ///   - error: The specific error that should trigger a retry.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that emits the same output as the upstream but retries on the specified error up to the specified number of times.
    public func retry<E: Error & Equatable>(_ retries: UInt = 1, on error: E) -> some AsynchronousUnitOfWork<Success> {
        Workers.RetryOn(upstream: self, retries: retries, error: error)
    }
}
