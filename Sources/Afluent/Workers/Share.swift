//
//  Share.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation

extension Workers {
    actor Share<Upstream: AsynchronousUnitOfWork, Success: Sendable>: AsynchronousUnitOfWork
    where Upstream.Success == Success {
        let state = TaskState<Success>()
        let upstream: Upstream
        private lazy var task = Task { try await upstream.operation() }

        init(upstream: Upstream) {
            self.upstream = upstream
        }

        public var result: Result<Success, Error> {
            get async {
                await task.result
            }
        }

        public func _operation() async throws -> AsynchronousOperation<Success> {
            AsynchronousOperation { [weak self] in
                guard let self else { throw CancellationError() }
                return try await self.task.value
            }
        }

        @discardableResult public func execute() async throws -> Success {
            try await result.get()
        }

        public nonisolated func run() {
            Task { try await task.value }
        }

        public nonisolated func cancel() {
            state.cancel()
            Task { await task.cancel() }
        }
    }
}

extension AsynchronousUnitOfWork {
    /// Shares the result of this unit of work among multiple subscribers, ensuring the upstream operation is only performed once.
    ///
    /// Use this operator to avoid duplicate work when multiple parts of your code need the result of the same asynchronous operation.
    ///
    /// ## Example
    /// ```swift
    /// let sharedTask = DeferredTask { UUID() }
    ///     .share()
    ///
    /// async let value1 = sharedTask.execute()
    /// async let value2 = sharedTask.execute()
    /// let (a, b) = try await (value1, value2)
    /// // 'a' and 'b' are guaranteed to be the same UUID instance
    /// ```
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that shares a single execution among all subscribers.
    /// - Note: The upstream operation runs only once, regardless of the number of calls to `execute()`.
    public func share() -> some AsynchronousUnitOfWork<Success> & Actor {
        Workers.Share(upstream: self)
    }
}
