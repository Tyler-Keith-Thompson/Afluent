//
//  Zip.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation

extension Workers {
    struct Zip<Success: Sendable>: AsynchronousUnitOfWork {
        let state: TaskState<Success>
        
        init<U: AsynchronousUnitOfWork, D: AsynchronousUnitOfWork>(upstream: U, downstream: D) where Success == (U.Success, D.Success) {
            state = TaskState {
                async let u = try await upstream.operation()
                async let d = try await downstream.operation()
                return (try await u, try await d)
            }
        }
    }
    
    struct Zip3<Success: Sendable>: AsynchronousUnitOfWork {
        let state: TaskState<Success>
        
        init<U: AsynchronousUnitOfWork, D0: AsynchronousUnitOfWork, D1: AsynchronousUnitOfWork>(upstream: U, d0: D0, d1: D1) where Success == (U.Success, D0.Success, D1.Success) {
            state = TaskState {
                async let u = try await upstream.operation()
                async let d_0 = try await d0.operation()
                async let d_1 = try await d1.operation()
                
                return (try await u, try await d_0, try await d_1)
            }
        }
    }
    
    struct Zip4<Success: Sendable>: AsynchronousUnitOfWork {
        let state: TaskState<Success>
        
        init<U: AsynchronousUnitOfWork, D0: AsynchronousUnitOfWork, D1: AsynchronousUnitOfWork, D2: AsynchronousUnitOfWork>(upstream: U, d0: D0, d1: D1, d2: D2) where Success == (U.Success, D0.Success, D1.Success, D2.Success) {
            state = TaskState {
                async let u = try await upstream.operation()
                async let d_0 = try await d0.operation()
                async let d_1 = try await d1.operation()
                async let d_2 = try await d2.operation()
                
                return (try await u, try await d_0, try await d_1, try await d_2)
            }
        }
    }
}

extension AsynchronousUnitOfWork {
    /// Zips the result of the current unit of work with another asynchronous unit of work.
    ///
    /// - Parameters:
    ///   - downstream: The second asynchronous unit of work to zip with.
    /// - Returns: A new asynchronous unit of work that produces a tuple containing results from both upstream and downstream when completed.
    public func zip<D: AsynchronousUnitOfWork>(_ downstream: D) -> some AsynchronousUnitOfWork<(Success, D.Success)> {
        Workers.Zip(upstream: self, downstream: downstream)
    }
    
    /// Zips the result of the current unit of work with another and applies a transform function.
    ///
    /// - Parameters:
    ///   - downstream: The second asynchronous unit of work to zip with.
    ///   - transform: A function that takes a tuple of results from both units of work and returns a transformed result.
    /// - Returns: A new asynchronous unit of work that produces the transformed result when completed.
    public func zip<D: AsynchronousUnitOfWork, T: Sendable>(_ downstream: D, @_inheritActorContext @_implicitSelfCapture transform: @escaping @Sendable ((Success, D.Success)) async throws -> T) -> some AsynchronousUnitOfWork<T> {
        Workers.TryMap<T>(upstream: Workers.Zip<(Success, D.Success)>(upstream: self, downstream: downstream), transform: transform)
    }
    
    // zip3
    /// Zips the result of the current unit of work with two other asynchronous units of work.
    ///
    /// - Parameters:
    ///   - d0: The first additional asynchronous unit of work to zip with.
    ///   - d1: The second additional asynchronous unit of work to zip with.
    /// - Returns: A new asynchronous unit of work that produces a tuple containing results from the upstream and both downstreams when completed.
    public func zip<D0: AsynchronousUnitOfWork, D1: AsynchronousUnitOfWork>(_ d0: D0, _ d1: D1) -> some AsynchronousUnitOfWork<(Success, D0.Success, D1.Success)> {
        Workers.Zip3(upstream: self, d0: d0, d1: d1)
    }
    
    /// Zips the result of the current unit of work with two other units of work and applies a transform function.
    ///
    /// - Parameters:
    ///   - d0: The first additional asynchronous unit of work to zip with.
    ///   - d1: The second additional asynchronous unit of work to zip with.
    ///   - transform: A function that takes a tuple of results from all units of work and returns a transformed result.
    /// - Returns: A new asynchronous unit of work that produces the transformed result when completed.
    public func zip<D0: AsynchronousUnitOfWork, D1: AsynchronousUnitOfWork, T: Sendable>(_ d0: D0, _ d1: D1, @_inheritActorContext @_implicitSelfCapture transform: @escaping @Sendable ((Success, D0.Success, D1.Success)) async throws -> T) -> some AsynchronousUnitOfWork<T> {
        Workers.TryMap<T>(upstream: Workers.Zip3<(Success, D0.Success, D1.Success)>(upstream: self, d0: d0, d1: d1), transform: transform)
    }
    
    // zip4
    /// Zips the result of the current unit of work with three other asynchronous units of work.
    ///
    /// - Parameters:
    ///   - d0: The first additional asynchronous unit of work to zip with.
    ///   - d1: The second additional asynchronous unit of work to zip with.
    ///   - d2: The third additional asynchronous unit of work to zip with.
    /// - Returns: A new asynchronous unit of work that produces a tuple containing results from the upstream and all three downstreams when completed.
    public func zip<D0: AsynchronousUnitOfWork, D1: AsynchronousUnitOfWork, D2: AsynchronousUnitOfWork>(_ d0: D0, _ d1: D1, _ d2: D2) -> some AsynchronousUnitOfWork<(Success, D0.Success, D1.Success, D2.Success)> {
        Workers.Zip4(upstream: self, d0: d0, d1: d1, d2: d2)
    }
    
    /// Zips the result of the current unit of work with three other units of work and applies a transform function.
    ///
    /// - Parameters:
    ///   - d0: The first additional asynchronous unit of work to zip with.
    ///   - d1: The second additional asynchronous unit of work to zip with.
    ///   - d2: The third additional asynchronous unit of work to zip with.
    ///   - transform: A function that takes a tuple of results from all units of work and returns a transformed result.
    /// - Returns: A new asynchronous unit of work that produces the transformed result when completed.
    public func zip<D0: AsynchronousUnitOfWork, D1: AsynchronousUnitOfWork, D2: AsynchronousUnitOfWork, T: Sendable>(_ d0: D0, _ d1: D1, _ d2: D2, @_inheritActorContext @_implicitSelfCapture transform: @escaping @Sendable ((Success, D0.Success, D1.Success, D2.Success)) async throws -> T) -> some AsynchronousUnitOfWork<T> {
        Workers.TryMap<T>(upstream: Workers.Zip4<(Success, D0.Success, D1.Success, D2.Success)>(upstream: self, d0: d0, d1: d1, d2: d2), transform: transform)
    }
}
