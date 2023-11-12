//
//  Retry.swift
//  
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation

extension Workers {
    actor Retry<Upstream: AsynchronousUnitOfWork, Success>: AsynchronousUnitOfWork where Upstream.Success == Success {
        var retryCount: UInt

        let state = TaskState<Success>()
        let upstream: Upstream

        init(upstream: Upstream, retries: UInt) {
            self.upstream = upstream
            retryCount = retries
        }
        
        func _operation() async throws -> Success {
            guard retryCount > 0 else {
                return try await upstream._operation()
            }
            
            while retryCount > 0 {
                do {
                    return try await upstream.operation()
                } catch {
                    guard !(error is CancellationError) else { throw error }
                    
                    decrementRetry()
                    continue
                }
            }
            return try await upstream.operation()
        }
        
        func decrementRetry() {
            guard retryCount > 0 else { return }
            retryCount -= 1
        }
    }
    
    actor RetryOn<Upstream: AsynchronousUnitOfWork, Failure: Error & Equatable, Success>: AsynchronousUnitOfWork where Upstream.Success == Success {
        var retryCount: UInt

        let state = TaskState<Success>()
        let upstream: Upstream
        let error: Failure

        init(upstream: Upstream, retries: UInt, error: Failure) {
            self.upstream = upstream
            retryCount = retries
            self.error = error
        }
        
        func _operation() async throws -> Success {
            guard retryCount > 0 else {
                return try await upstream._operation()
            }

            while retryCount > 0 {
                do {
                    return try await upstream.operation()
                } catch(let err) {
                    guard !(error is CancellationError) else { throw error }

                    guard let unwrappedError = (err as? Failure),
                          unwrappedError == error else { throw err }
                    decrementRetry()
                    continue
                }
            }
            return try await upstream.operation()
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
