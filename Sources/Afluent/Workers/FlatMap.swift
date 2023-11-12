//
//  FlatMap.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation

extension Workers {
    struct FlatMap<Upstream: AsynchronousUnitOfWork, Downstream: AsynchronousUnitOfWork, Success: Sendable>: AsynchronousUnitOfWork where Success == Downstream.Success {
        let state = TaskState<Success>()
        let upstream: Upstream
        let transform: @Sendable (Upstream.Success) async throws -> Downstream

        init(upstream: Upstream, @_inheritActorContext @_implicitSelfCapture transform: @escaping @Sendable (Upstream.Success) async throws -> Downstream) {
            self.upstream = upstream
            self.transform = transform
        }
        
        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation {
                try await transform(try await upstream.operation()).operation()
            }
        }
    }
}

extension AsynchronousUnitOfWork {
    /// Transforms the successful output values from the upstream `AsynchronousUnitOfWork` using the provided asynchronous transformation closure.
    ///
    /// - Parameter transform: An asynchronous closure that takes a successful output value and returns another `AsynchronousUnitOfWork`.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` emitting the successful output values from the new `AsynchronousUnitOfWork` created by the transformation.
    ///
    /// - Note: The returned `AsynchronousUnitOfWork` will fail if either the upstream unit of work or the transformation closure fails.
    public func flatMap<D: AsynchronousUnitOfWork>(@_inheritActorContext @_implicitSelfCapture _ transform: @escaping @Sendable (Success) async throws -> D) -> some AsynchronousUnitOfWork<D.Success> {
        Workers.FlatMap(upstream: self, transform: transform)
    }
    
    /// Transforms the successful output values from the upstream `AsynchronousUnitOfWork` using the provided asynchronous transformation closure.
    /// This overload is specialized for `AsynchronousUnitOfWork` types that have `Void` as their `Success` type.
    ///
    /// - Parameter transform: An asynchronous closure that returns another `AsynchronousUnitOfWork`.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` emitting the successful output values from the new `AsynchronousUnitOfWork` created by the transformation.
    ///
    /// - Note: The returned `AsynchronousUnitOfWork` will fail if either the upstream unit of work or the transformation closure fails.
    public func flatMap<D: AsynchronousUnitOfWork>(@_inheritActorContext @_implicitSelfCapture _ transform: @escaping @Sendable () async throws -> D) -> some AsynchronousUnitOfWork<D.Success> where Success == Void {
        Workers.FlatMap(upstream: self, transform: { _ in try await transform() })
    }
}
