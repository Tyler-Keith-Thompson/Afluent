import Foundation

extension Workers {
    /// A unit of work that carries a value beside the work it runs.
    ///
    /// Running, executing or cancelling it runs, executes or cancels its upstream, and it composes
    /// with every operator as its upstream does. ``value`` is there from the start, before the work
    /// runs. Create one with ``AsynchronousUnitOfWork/carrying(_:)``.
    public struct Carrying<Upstream: AsynchronousUnitOfWork, Value: Sendable>: AsynchronousUnitOfWork {
        public typealias Success = Upstream.Success

        let upstream: Upstream

        /// The value carried beside the work.
        public let value: Value

        init(upstream: Upstream, value: Value) {
            self.upstream = upstream
            self.value = value
        }

        // Each requirement calls the upstream's own implementation, as AnyAsynchronousUnitOfWork
        // does: an upstream such as `share()` replaces the protocol's defaults, and going through
        // `state` would skip that.

        @_spi(Conformance) public var state: TaskState<Success> {
            upstream.state
        }

        public var result: Result<Success, Error> {
            get async throws {
                try await upstream.result
            }
        }

        public func run(priority: TaskPriority?) {
            upstream.run(priority: priority)
        }

        @discardableResult
        public func execute(priority: TaskPriority?) async throws -> Success {
            try await upstream.execute(priority: priority)
        }

        @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
        public func run(
            executorPreference taskExecutor: (any TaskExecutor)?, priority: TaskPriority?
        ) {
            upstream.run(executorPreference: taskExecutor, priority: priority)
        }

        @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
        @discardableResult
        public func execute(
            executorPreference taskExecutor: (any TaskExecutor)?, priority: TaskPriority?
        ) async throws -> Success {
            try await upstream.execute(executorPreference: taskExecutor, priority: priority)
        }

        @Sendable
        @_spi(Conformance) public func _operation() async throws -> AsynchronousOperation<Success> {
            try await upstream._operation()
        }

        public func cancel() {
            upstream.cancel()
        }
    }
}

extension AsynchronousUnitOfWork {
    /// Returns this unit of work carrying `value` beside it.
    ///
    /// Use it to return a unit of work together with something the caller reads besides its
    /// result, such as a stream of progress or a handle to the resource the work creates. The
    /// result still composes with every operator, and running, executing or cancelling it acts on
    /// this unit of work.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let (progress, continuation) = AsyncStream<Double>.makeStream()
    /// let upload = DeferredTask {
    ///     continuation.yield(1)
    ///     continuation.finish()
    ///     return 201
    /// }
    /// .carrying(progress)
    ///
    /// let status = try await upload.map(String.init).execute() // "201"
    /// for await fraction in upload.value { print(fraction) } // Prints: 1.0
    /// ```
    ///
    /// - Parameter value: The value to carry, read back from ``Workers/Carrying/value``.
    /// - Returns: A unit of work that runs this one and carries `value`.
    public func carrying<Value: Sendable>(_ value: Value) -> Workers.Carrying<Self, Value> {
        Workers.Carrying(upstream: self, value: value)
    }
}
