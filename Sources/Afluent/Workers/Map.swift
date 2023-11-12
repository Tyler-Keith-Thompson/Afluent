//
//  Map.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation

extension Workers {
    struct Map<Upstream: AsynchronousUnitOfWork, Success: Sendable>: AsynchronousUnitOfWork {
        let state = TaskState<Success>()
        let upstream: Upstream
        let transform: @Sendable (Upstream.Success) async -> Success

        init(upstream: Upstream, @_inheritActorContext @_implicitSelfCapture transform: @escaping @Sendable (Upstream.Success) async -> Success) {
            self.upstream = upstream
            self.transform = transform
        }
        
        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation {
                await transform(try await upstream.operation())
            }
        }
    }
    
    struct TryMap<Upstream: AsynchronousUnitOfWork, Success: Sendable>: AsynchronousUnitOfWork {
        let state = TaskState<Success>()
        let upstream: Upstream
        let transform: @Sendable (Upstream.Success) async throws -> Success

        init(upstream: Upstream, @_inheritActorContext @_implicitSelfCapture transform: @escaping @Sendable (Upstream.Success) async throws -> Success) {
            self.upstream = upstream
            self.transform = transform
        }
        
        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation {
                try await transform(try await upstream.operation())
            }
        }
    }
}

extension AsynchronousUnitOfWork {
    /// Transforms the successful output of the upstream `AsynchronousUnitOfWork` using a provided closure.
    ///
    /// - Parameters:
    ///   - transform: A closure that takes the successful output of the upstream and returns a transformed value.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that emits the transformed value.
    public func map<S: Sendable>(@_inheritActorContext @_implicitSelfCapture _ transform: @escaping @Sendable (Success) async -> S) -> some AsynchronousUnitOfWork<S> {
        Workers.Map(upstream: self, transform: transform)
    }
    
    /// Transforms the successful output of the upstream `AsynchronousUnitOfWork` using a provided key path.
    ///
    /// - Parameters:
    ///   - keyPath: A key path to a property of the upstream's output type.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that emits the value of the property specified by the key path.
    public func map<T>(_ keyPath: KeyPath<Success, T>) -> some AsynchronousUnitOfWork<T> {
        Workers.Map(upstream: self) {
            $0[keyPath: keyPath]
        }
    }
    
    /// Transforms the successful output of the upstream `AsynchronousUnitOfWork` using a provided closure that can throw errors.
    ///
    /// - Parameters:
    ///   - transform: A closure that takes the successful output of the upstream and returns a transformed value. The closure can throw errors.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that emits the transformed value or an error if the transformation fails.
    public func tryMap<S: Sendable>(@_inheritActorContext @_implicitSelfCapture _ transform: @escaping @Sendable (Success) async throws -> S) -> some AsynchronousUnitOfWork<S> {
        Workers.TryMap(upstream: self, transform: transform)
    }
}
