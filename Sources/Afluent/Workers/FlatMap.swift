//
//  FlatMap.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation

extension Workers {
    struct FlatMap<
        Upstream: AsynchronousUnitOfWork, Downstream: AsynchronousUnitOfWork, Success: Sendable
    >: AsynchronousUnitOfWork where Success == Downstream.Success {
        let state = TaskState<Success>()
        let upstream: Upstream
        let transform: @Sendable (Upstream.Success) async throws -> Downstream

        init(
            upstream: Upstream,
            @_inheritActorContext @_implicitSelfCapture transform: @Sendable @escaping (
                Upstream.Success
            ) async throws -> Downstream
        ) {
            self.upstream = upstream
            self.transform = transform
        }

        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation {
                try await transform(await upstream.operation()).operation()
            }
        }
    }
}

extension AsynchronousUnitOfWork {
    /// Transforms the successful output value from the upstream unit of work by applying an asynchronous transformation, returning the result of a new unit of work.
    ///
    /// Use this operator to chain dependent asynchronous operations, where the output of the first is needed to create the second.
    ///
    /// ## Example
    /// ```
    /// let profile = try await DeferredTask { try await fetchUser() }
    ///     .flatMap { user in DeferredTask { try await fetchProfile(for: user) } }
    ///     .execute()
    /// ```
    ///
    /// - Parameter transform: An asynchronous closure that takes the upstream value and returns a new unit of work.
    /// - Returns: An `AsynchronousUnitOfWork` emitting the successful output of the downstream unit of work.
    /// - Note: The returned unit of work fails if either the upstream or the transformation closure fails.
    public func flatMap<D: AsynchronousUnitOfWork>(
        @_inheritActorContext @_implicitSelfCapture _ transform: @Sendable @escaping (Success)
            async throws -> D
    ) -> some AsynchronousUnitOfWork<D.Success> {
        Workers.FlatMap(upstream: self, transform: transform)
    }

    /// Transforms a unit of work that emits `Void` by applying an asynchronous closure that produces a new unit of work.
    ///
    /// This is convenient for chaining side-effectful async operations where the upstream does not yield a value.
    ///
    /// ## Example
    /// ```
    /// let value = try await DeferredTask { }
    ///     .flatMap { DeferredTask { 42 } }
    ///     .execute()
    /// ```
    ///
    /// - Parameter transform: An async closure returning the next unit of work.
    /// - Returns: An `AsynchronousUnitOfWork` emitting the output of the downstream unit.
    /// - Note: The returned unit of work fails if either the upstream or the transformation closure fails.
    public func flatMap<D: AsynchronousUnitOfWork>(
        @_inheritActorContext @_implicitSelfCapture _ transform: @Sendable @escaping () async throws
            -> D
    ) -> some AsynchronousUnitOfWork<D.Success> where Success == Void {
        Workers.FlatMap(upstream: self, transform: { _ in try await transform() })
    }
}

