////
////  AnyCancellable.swift
////
////
////  Created by Tyler Thompson on 10/30/23.
////
//
//import Foundation
//
///// Stores an erased unit of work and provides a mechanism to cancel it
///// - NOTE: The unit of work will be cancelled when the AnyCancellable is deinitialized
//public final class AnyCancellable: Hashable, Sendable {
//    public static func == (lhs: AnyCancellable, rhs: AnyCancellable) -> Bool {
//        lhs === rhs
//    }
//
//    let unitOfWork: any AsynchronousUnitOfWork
//    init<U: AsynchronousUnitOfWork>(_ upstream: U) {
//        unitOfWork = upstream
//    }
//
//    deinit {
//        cancel()
//    }
//
//    public func hash(into hasher: inout Hasher) {
//        hasher.combine(ObjectIdentifier(self))
//    }
//
//    /// Cancels the asynchronous unit of work
//    public func cancel() {
//        unitOfWork.cancel()
//    }
//
//    /// Stores this type-erasing cancellable instance in the specified collection.
//    public func store(in collection: inout some RangeReplaceableCollection<AnyCancellable>) {
//        collection.append(self)
//    }
//
//    /// Stores this type-erasing cancellable instance in the specified set.
//    public func store(in set: inout Set<AnyCancellable>) {
//        set.insert(self)
//    }
//}
//
//extension AsynchronousUnitOfWork {
//    /// Executes the current asynchronous unit of work and returns an AnyCancellable token to cancel the subscription
//    public func subscribe(priority: TaskPriority? = nil) -> AnyCancellable {
//        defer { run(priority: priority) }
//        return AnyCancellable(self)
//    }
//
//    #if swift(>=6)
//        /// Executes the current asynchronous unit of work and returns an AnyCancellable token to cancel the subscription
//        @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
//        public func subscribe(
//            executorPreference taskExecutor: (any TaskExecutor)?, priority: TaskPriority? = nil
//        ) -> AnyCancellable {
//            defer { run(executorPreference: taskExecutor, priority: priority) }
//            return AnyCancellable(self)
//        }
//    #endif
//}
//
//extension AsyncSequence where Self: Sendable {
//    /// Executes the current async sequence and returns an AnyCancellable token to cancel the subscription.
//    ///
//    /// - Parameters:
//    ///   - receiveCompletion: A function that is executed when the stream has completed normally with `nil` or an error.
//    ///   - receiveOutput: A function that is executed when output is received from the sequence.
//    ///   If this function throws an error, then the stream is completed.
//    public func sink(
//        receiveCompletion: (@Sendable (AsyncSequences.Completion<Error>) async -> Void)? = nil,
//        receiveOutput: (@Sendable (Element) async throws -> Void)? = nil
//    ) -> AnyCancellable {
//        DeferredTask {
//            do {
//                for try await output in self {
//                    try await receiveOutput?(output)
//                }
//                await receiveCompletion?(.finished)
//            } catch {
//                await receiveCompletion?(.failure(error))
//            }
//        }
//        .subscribe()
//    }
//}
//
//extension AsyncSequences {
//    /// A type that represents the completion of a sequence, either due to a normal completion with `nil` or an error.
//    public enum Completion<Failure: Error> {
//        /// The sequence finished normally.
//        case finished
//        /// The sequence completed due to the indicated error.
//        case failure(Failure)
//    }
//}
