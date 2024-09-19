//
//  Retry.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation

extension Workers {
    actor Retry<Upstream: AsynchronousUnitOfWork, Success, Strategy: RetryStrategy>: AsynchronousUnitOfWork where Upstream.Success == Success {
        let state = TaskState<Success>()
        let upstream: Upstream
        var strategy: Strategy

        init(upstream: Upstream, strategy: Strategy) {
            self.upstream = upstream
            self.strategy = strategy
        }

        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation { [weak self] in
                guard let self else { throw CancellationError() }

                do {
                    return try await self.upstream._operation()()
                } catch {
                    var err = error
                    while try await strategy.handle(error: err) {
                        do {
                            return try await self.upstream._operation()()
                        } catch {
                            err = error
                        }
                    }
                    throw err
                }
            }
        }
    }
    
    actor RetryOn<Upstream: AsynchronousUnitOfWork, Failure: Error & Equatable, Success, Strategy: RetryStrategy>: AsynchronousUnitOfWork where Upstream.Success == Success {
        let state = TaskState<Success>()
        let upstream: Upstream
        let strategy: Strategy
        let error: Failure
        
        init(upstream: Upstream, strategy: Strategy, error: Failure) {
            self.upstream = upstream
            self.strategy = strategy
            self.error = error
        }
        
        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation { [weak self] in
                guard let self else { throw CancellationError() }
                do {
                    return try await self.upstream._operation()()
                } catch {
                    var err = error
                    while try await strategy.handle(error: err) {
                        try err.throwIf(CancellationError.self)
                            .throwIf(not: self.error)

                        do {
                            return try await self.upstream._operation()()
                        } catch {
                            err = error
                        }
                    }
                    throw err
                }
            }
        }
    }
}

extension AsynchronousUnitOfWork {
    /// Retries the upstream `AsynchronousUnitOfWork` up to a specified number of times.
    ///
    /// - Parameter strategy: The retry strategy to use.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that emits the same output as the upstream but retries on failure up to the specified number of times.
    public func retry(_ strategy: some RetryStrategy) -> some AsynchronousUnitOfWork<Success> {
        Workers.Retry(upstream: self, strategy: strategy)
    }
    
    /// Retries the upstream `AsynchronousUnitOfWork` up to a specified number of times.
    ///
    /// - Parameter retries: The maximum number of times to retry the upstream, defaulting to 1.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that emits the same output as the upstream but retries on failure up to the specified number of times.
    public func retry(_ retries: UInt = 1) -> some AsynchronousUnitOfWork<Success> {
        Workers.Retry(upstream: self, strategy: .byCount(retries))
    }

    /// Retries the upstream `AsynchronousUnitOfWork` up to a specified number of times only when a specific error occurs.
    ///
    /// - Parameters:
    ///   - retries: The maximum number of times to retry the upstream, defaulting to 1.
    ///   - error: The specific error that should trigger a retry.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that emits the same output as the upstream but retries on the specified error up to the specified number of times.
    public func retry<E: Error & Equatable>(_ retries: UInt = 1, on error: E) -> some AsynchronousUnitOfWork<Success> {
        Workers.RetryOn(upstream: self, strategy: .byCount(retries), error: error)
    }
}

public protocol RetryStrategy: Sendable {
    func handle(error: Error, beforeRetry: @Sendable (Error) async throws -> Void) async throws -> Bool
}

extension RetryStrategy {
    func handle(error err: Error) async throws -> Bool {
        try await handle(error: err, beforeRetry: { _ in })
    }
}

extension RetryStrategy where Self == RetryByCountStrategy {
    public static func byCount(_ count: UInt) -> RetryByCountStrategy {
        return RetryByCountStrategy(retryCount: count)
    }
}

public actor RetryByCountStrategy: RetryStrategy {
    var retryCount: UInt
    
    public init(retryCount: UInt) {
        self.retryCount = retryCount
    }

    public func handle(error err: Error, beforeRetry: @Sendable (Error) async throws -> Void) async throws -> Bool {
        guard retryCount > 0 else {
            return false
        }
        
        try await beforeRetry(err)
        decrementRetry()
        return true
    }
    
    func decrementRetry() {
        guard retryCount > 0 else { return }
        retryCount -= 1
    }
}
