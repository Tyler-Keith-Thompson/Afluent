////
////  EraseToAnyAsynchronousUnitOfWorkTests.swift
////
////
////  Created by Tyler Thompson on 10/30/23.
////
//
//import Afluent
//import Foundation
//import Testing
//
//struct EraseToAnyAsynchronousUnitOfWorkTests {
//    @Test func erasureOfUnitOfWork() async throws {
//        let val = try await DeferredTask { true }
//            .flatMap { branch -> AnyAsynchronousUnitOfWork<Int> in
//                if branch {
//                    return DeferredTask { 1 }.eraseToAnyUnitOfWork()
//                } else {
//                    return DeferredTask { 0 }.eraseToAnyUnitOfWork()
//                }
//            }.execute()
//
//        #expect(val == 1)
//    }
//
//    @Test func erasureOfUnitOfWork_OtherBranch() async throws {
//        let val = try await DeferredTask { false }
//            .flatMap { branch -> AnyAsynchronousUnitOfWork<Int> in
//                if branch {
//                    return DeferredTask { 1 }.eraseToAnyUnitOfWork()
//                } else {
//                    return DeferredTask { 0 }.eraseToAnyUnitOfWork()
//                }
//            }.execute()
//
//        #expect(val == 0)
//    }
//
//    @Test func accomodatesCustomProtocolImplementations() async throws {
//        final class FunctionCallTrackingWorker<Success: Sendable>: AsynchronousUnitOfWork,
//            @unchecked Sendable
//        {
//            init(upstream: any AsynchronousUnitOfWork<Success>) {
//                self.upstream = upstream
//            }
//            let upstream: any AsynchronousUnitOfWork<Success>
//            var functionCalls: [String] = []
//
//            public var state: TaskState<Success> {
//                functionCalls.append(#function)
//                return upstream.state
//            }
//            public var result: Result<Success, Error> {
//                get async throws {
//                    functionCalls.append(#function)
//                    return try await upstream.result
//                }
//            }
//            public func run(priority: TaskPriority?) {
//                functionCalls.append(#function)
//                return upstream.run(priority: priority)
//            }
//            @discardableResult
//            public func execute(priority: TaskPriority?) async throws -> Success {
//                functionCalls.append(#function)
//                return try await upstream.execute(priority: priority)
//            }
//            #if swift(>=6)
//                @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
//                public func run(
//                    executorPreference taskExecutor: (any TaskExecutor)?, priority: TaskPriority?
//                ) {
//                    functionCalls.append(#function)
//                    return upstream.run(executorPreference: taskExecutor, priority: priority)
//                }
//                @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
//                @discardableResult
//                public func execute(
//                    executorPreference taskExecutor: (any TaskExecutor)?, priority: TaskPriority?
//                ) async throws -> Success {
//                    functionCalls.append(#function)
//                    return try await upstream.execute(
//                        executorPreference: taskExecutor, priority: priority)
//                }
//            #endif
//            @Sendable
//            public func _operation() async throws -> AsynchronousOperation<Success> {
//                functionCalls.append(#function)
//                return try await upstream._operation()
//            }
//            public func cancel() {
//                functionCalls.append(#function)
//                return upstream.cancel()
//            }
//        }
//
//        let worker = FunctionCallTrackingWorker(upstream: DeferredTask { 0 })
//        let erased = worker.eraseToAnyUnitOfWork()
//
//        _ = erased.state
//        #expect(worker.functionCalls == ["state"])
//        worker.functionCalls.removeAll()
//
//        _ = try await erased.result
//        #expect(worker.functionCalls == ["result"])
//        worker.functionCalls.removeAll()
//
//        erased.run(priority: nil)
//        #expect(worker.functionCalls == ["run(priority:)"])
//        worker.functionCalls.removeAll()
//
//        try await erased.execute(priority: nil)
//        #expect(worker.functionCalls == ["execute(priority:)"])
//        worker.functionCalls.removeAll()
//
//        #if swift(>=6)
//            if #available(macOS 15.0, *) {
//                erased.run(executorPreference: nil, priority: nil)
//                #expect(worker.functionCalls == ["run(executorPreference:priority:)"])
//                worker.functionCalls.removeAll()
//
//                try await erased.execute(executorPreference: nil, priority: nil)
//                #expect(worker.functionCalls == ["execute(executorPreference:priority:)"])
//                worker.functionCalls.removeAll()
//            }
//        #endif
//
//        _ = try await erased._operation()
//        #expect(worker.functionCalls == ["_operation()"])
//        worker.functionCalls.removeAll()
//
//        erased.cancel()
//        #expect(worker.functionCalls == ["cancel()"])
//        worker.functionCalls.removeAll()
//    }
//}
