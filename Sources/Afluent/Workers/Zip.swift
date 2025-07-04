//
//  Zip.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation

extension Workers {
    struct Zip<Upstream: AsynchronousUnitOfWork, Downstream: AsynchronousUnitOfWork>:
        AsynchronousUnitOfWork
    {
        typealias Success = (Upstream.Success, Downstream.Success)

        let state = TaskState<Success>()
        let upstream: Upstream
        let downstream: Downstream

        init(upstream: Upstream, downstream: Downstream) {
            self.upstream = upstream
            self.downstream = downstream
        }

        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation {
                async let u = try await upstream.operation()
                async let d = try await downstream.operation()
                return try (await u, await d)
            }
        }
    }

    struct Zip3<
        Upstream: AsynchronousUnitOfWork, Downstream0: AsynchronousUnitOfWork,
        Downstream1: AsynchronousUnitOfWork
    >: AsynchronousUnitOfWork {
        typealias Success = (Upstream.Success, Downstream0.Success, Downstream1.Success)

        let state = TaskState<Success>()
        let upstream: Upstream
        let d0: Downstream0
        let d1: Downstream1

        init(upstream: Upstream, d0: Downstream0, d1: Downstream1) {
            self.upstream = upstream
            self.d0 = d0
            self.d1 = d1
        }

        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation {
                async let u = try await upstream.operation()
                async let d_0 = try await d0.operation()
                async let d_1 = try await d1.operation()

                return try (await u, await d_0, await d_1)
            }
        }
    }

    struct Zip4<
        Upstream: AsynchronousUnitOfWork, Downstream0: AsynchronousUnitOfWork,
        Downstream1: AsynchronousUnitOfWork, Downstream2: AsynchronousUnitOfWork
    >: AsynchronousUnitOfWork {
        typealias Success = (
            Upstream.Success, Downstream0.Success, Downstream1.Success, Downstream2.Success
        )

        let state = TaskState<Success>()
        let upstream: Upstream
        let d0: Downstream0
        let d1: Downstream1
        let d2: Downstream2

        init(upstream: Upstream, d0: Downstream0, d1: Downstream1, d2: Downstream2) {
            self.upstream = upstream
            self.d0 = d0
            self.d1 = d1
            self.d2 = d2
        }

        func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation {
                async let u = try await upstream.operation()
                async let d_0 = try await d0.operation()
                async let d_1 = try await d1.operation()
                async let d_2 = try await d2.operation()

                return try (await u, await d_0, await d_1, await d_2)
            }
        }
    }
}

extension AsynchronousUnitOfWork {
    /// Zips the result of this unit of work with another, producing a tuple of both results when both complete.
    ///
    /// ## Example
    /// ```swift
    /// let zipped = DeferredTask { "a" }
    ///     .zip(DeferredTask { 42 })
    /// let (str, num) = try await zipped.execute()
    /// // 'str' is "a", 'num' is 42
    /// ```
    ///
    /// - Parameter downstream: The unit of work to zip with.
    /// - Returns: An `AsynchronousUnitOfWork` producing a tuple of both results.
    public func zip<D: AsynchronousUnitOfWork>(_ downstream: D) -> some AsynchronousUnitOfWork<
        (Success, D.Success)
    > {
        Workers.Zip(upstream: self, downstream: downstream)
    }

    /// Zips the result of this unit of work with another and applies a transform function.
    ///
    /// ## Example
    /// ```swift
    /// let zipped = DeferredTask { "a" }
    ///     .zip(DeferredTask { 42 }) { (str, num) in
    ///         "\(str): \(num)"
    ///     }
    /// let result = try await zipped.execute()
    /// // result is "a: 42"
    /// ```
    ///
    /// - Parameter downstream: The unit of work to zip with.
    /// - Parameter transform: Closure combining both results.
    /// - Returns: An `AsynchronousUnitOfWork` producing the transformed result.
    public func zip<D: AsynchronousUnitOfWork, T: Sendable>(
        _ downstream: D,
        @_inheritActorContext @_implicitSelfCapture transform: @Sendable @escaping (
            (Success, D.Success)
        ) async throws -> T
    ) -> some AsynchronousUnitOfWork<T> {
        Workers.TryMap<Workers.Zip<Self, D>, T>(
            upstream: Workers.Zip<Self, D>(upstream: self, downstream: downstream),
            transform: transform)
    }

    // zip3
    /// Zips the result of this unit of work with two other asynchronous units of work, producing a tuple of all three results.
    ///
    /// ## Example
    /// ```swift
    /// let zipped = DeferredTask { "a" }
    ///     .zip(DeferredTask { 42 }, DeferredTask { true })
    /// let (str, num, bool) = try await zipped.execute()
    /// // 'str' is "a", 'num' is 42, 'bool' is true
    /// ```
    ///
    /// - Parameters:
    ///   - d0: The first additional unit of work to zip with.
    ///   - d1: The second additional unit of work to zip with.
    /// - Returns: An `AsynchronousUnitOfWork` producing a tuple of all three results.
    public func zip<D0: AsynchronousUnitOfWork, D1: AsynchronousUnitOfWork>(_ d0: D0, _ d1: D1)
        -> some AsynchronousUnitOfWork<(Success, D0.Success, D1.Success)>
    {
        Workers.Zip3(upstream: self, d0: d0, d1: d1)
    }

    /// Zips the result of this unit of work with two others and applies a transform function.
    ///
    /// ## Example
    /// ```swift
    /// let zipped = DeferredTask { "a" }
    ///     .zip(DeferredTask { 42 }, DeferredTask { true }) { (str, num, bool) in
    ///         "\(str): \(num), flag is \(bool)"
    ///     }
    /// let result = try await zipped.execute()
    /// // result is "a: 42, flag is true"
    /// ```
    ///
    /// - Parameters:
    ///   - d0: The first additional unit of work to zip with.
    ///   - d1: The second additional unit of work to zip with.
    ///   - transform: Closure combining all three results.
    /// - Returns: An `AsynchronousUnitOfWork` producing the transformed result.
    public func zip<D0: AsynchronousUnitOfWork, D1: AsynchronousUnitOfWork, T: Sendable>(
        _ d0: D0, _ d1: D1,
        @_inheritActorContext @_implicitSelfCapture transform: @Sendable @escaping (
            (Success, D0.Success, D1.Success)
        ) async throws -> T
    ) -> some AsynchronousUnitOfWork<T> {
        Workers.TryMap<Workers.Zip3<Self, D0, D1>, T>(
            upstream: Workers.Zip3<Self, D0, D1>(upstream: self, d0: d0, d1: d1),
            transform: transform)
    }

    // zip4
    /// Zips the result of this unit of work with three other asynchronous units of work, producing a tuple of all four results.
    ///
    /// ## Example
    /// ```swift
    /// let zipped = DeferredTask { "a" }
    ///     .zip(DeferredTask { 42 }, DeferredTask { true }, DeferredTask { 3.14 })
    /// let (str, num, bool, pi) = try await zipped.execute()
    /// // 'str' is "a", 'num' is 42, 'bool' is true, 'pi' is 3.14
    /// ```
    ///
    /// - Parameters:
    ///   - d0: The first additional unit of work to zip with.
    ///   - d1: The second additional unit of work to zip with.
    ///   - d2: The third additional unit of work to zip with.
    /// - Returns: An `AsynchronousUnitOfWork` producing a tuple of all four results.
    public func zip<
        D0: AsynchronousUnitOfWork, D1: AsynchronousUnitOfWork, D2: AsynchronousUnitOfWork
    >(_ d0: D0, _ d1: D1, _ d2: D2) -> some AsynchronousUnitOfWork<
        (Success, D0.Success, D1.Success, D2.Success)
    > {
        Workers.Zip4(upstream: self, d0: d0, d1: d1, d2: d2)
    }

    /// Zips the result of this unit of work with three others and applies a transform function.
    ///
    /// ## Example
    /// ```swift
    /// let zipped = DeferredTask { "a" }
    ///     .zip(DeferredTask { 42 }, DeferredTask { true }, DeferredTask { 3.14 }) { (str, num, bool, pi) in
    ///         "\(str): \(num), flag is \(bool), π is \(pi)"
    ///     }
    /// let result = try await zipped.execute()
    /// // result is "a: 42, flag is true, π is 3.14"
    /// ```
    ///
    /// - Parameters:
    ///   - d0: The first additional unit of work to zip with.
    ///   - d1: The second additional unit of work to zip with.
    ///   - d2: The third additional unit of work to zip with.
    ///   - transform: Closure combining all four results.
    /// - Returns: An `AsynchronousUnitOfWork` producing the transformed result.
    public func zip<
        D0: AsynchronousUnitOfWork, D1: AsynchronousUnitOfWork, D2: AsynchronousUnitOfWork,
        T: Sendable
    >(
        _ d0: D0, _ d1: D1, _ d2: D2,
        @_inheritActorContext @_implicitSelfCapture transform: @Sendable @escaping (
            (Success, D0.Success, D1.Success, D2.Success)
        ) async throws -> T
    ) -> some AsynchronousUnitOfWork<T> {
        Workers.TryMap<Workers.Zip4<Self, D0, D1, D2>, T>(
            upstream: Workers.Zip4<Self, D0, D1, D2>(upstream: self, d0: d0, d1: d1, d2: d2),
            transform: transform)
    }
}
