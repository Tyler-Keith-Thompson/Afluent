//
//  Share.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation

extension Workers {
    actor Share<Success: Sendable>: AsynchronousUnitOfWork {
        let state: TaskState<Success>
        private lazy var task = state.setLazyTask()
        
        init<U: AsynchronousUnitOfWork>(upstream: U) where U.Success == Success {
            state = upstream.state
        }
        
        public var result: Result<Success, Error> {
            get async {
                await task.result
            }
        }
        
        @discardableResult public func execute() async throws -> Success {
            try await result.get()
        }
        
        nonisolated public func run() {
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
