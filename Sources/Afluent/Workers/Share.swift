//
//  Share.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation

extension Workers {
    actor Share<Upstream: AsynchronousUnitOfWork, Success: Sendable>: AsynchronousUnitOfWork where Upstream.Success == Success {
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
    }
}

extension AsynchronousUnitOfWork {
    /// Shares the upstream `AsynchronousUnitOfWork` among multiple downstream subscribers.
    ///
    /// - Returns: An `AsynchronousUnitOfWork` that shares a single subscription to the upstream, allowing multiple downstream subscribers to receive the same values.
    public func share() -> some AsynchronousUnitOfWork<Success> & AnyActor { Workers.Share(upstream: self) }
}
