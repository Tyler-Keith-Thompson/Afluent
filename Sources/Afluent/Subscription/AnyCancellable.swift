//
//  AnyCancellable.swift
//
//
//  Created by Tyler Thompson on 10/30/23.
//

import Foundation

/// Stores an erased unit of work and provides a mechanism to cancel it.
///
/// `AnyCancellable` acts as a type-erased token that manages the lifecycle of an asynchronous unit of work.
/// When this instance is deinitialized, the associated unit of work is automatically cancelled, ensuring
/// that ongoing asynchronous operations do not continue unnecessarily.
///
/// Use `AnyCancellable` to hold onto and control asynchronous tasks, typically returned from operations that
/// support cancellation.
///
/// ```swift
/// let cancellable = someAsynchronousUnitOfWork.subscribe()
/// // To cancel explicitly:
/// cancellable.cancel()
/// // Or let `cancellable` go out of scope to cancel automatically.
/// ```
public final class AnyCancellable: Hashable, Sendable {
    public static func == (lhs: AnyCancellable, rhs: AnyCancellable) -> Bool {
        lhs === rhs
    }

    let unitOfWork: any AsynchronousUnitOfWork
    init<U: AsynchronousUnitOfWork>(_ upstream: U) {
        unitOfWork = upstream
    }

    deinit {
        cancel()
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    /// Cancels the asynchronous unit of work immediately.
    ///
    /// Call this method to explicitly cancel the associated asynchronous operation before the
    /// `AnyCancellable` instance is deallocated. This prevents any further work or callbacks from
    /// occurring related to the unit of work.
    ///
    /// - Important: If not called manually, cancellation will occur automatically when this instance is deinitialized.
    public func cancel() {
        unitOfWork.cancel()
    }

    /// Stores this type-erasing cancellable instance in the specified collection.
    ///
    /// This is useful for managing multiple cancellables together, such as storing them in an array
    /// to maintain their lifetime for the duration of a scope.
    ///
    /// - Parameter collection: A range-replaceable collection of `AnyCancellable` to append to.
    /// 
    /// ```swift
    /// var cancellables: [AnyCancellable] = []
    /// someUnitOfWork.subscribe().store(in: &cancellables)
    /// ```
    public func store(in collection: inout some RangeReplaceableCollection<AnyCancellable>) {
        collection.append(self)
    }

    /// Stores this type-erasing cancellable instance in the specified set.
    ///
    /// This allows efficient management of cancellables with uniqueness guaranteed.
    ///
    /// - Parameter set: A set of `AnyCancellable` instances to insert into.
    ///
    /// ```swift
    /// var cancellableSet: Set<AnyCancellable> = []
    /// someUnitOfWork.subscribe().store(in: &cancellableSet)
    /// ```
    public func store(in set: inout Set<AnyCancellable>) {
        set.insert(self)
    }
}

extension AsynchronousUnitOfWork {
    /// Executes the current asynchronous unit of work and returns an `AnyCancellable` token to cancel the subscription.
    ///
    /// Calling this method starts the asynchronous operation immediately.
    /// The returned `AnyCancellable` instance can be held to keep the operation alive or cancelled to stop it early.
    ///
    /// - Parameter priority: Optional priority value to run the unit of work.
    /// - Returns: An `AnyCancellable` token that can be used to cancel the running operation.
    ///
    /// - Note: The operation will also be cancelled automatically when the returned token is deinitialized.
    ///
    /// Usage example:
    /// ```swift
    /// let cancellable = networkRequest.subscribe(priority: .userInitiated)
    /// // Later, if needed:
    /// cancellable.cancel()
    /// ```
    public func subscribe(priority: TaskPriority? = nil) -> AnyCancellable {
        defer { run(priority: priority) }
        return AnyCancellable(self)
    }

    #if swift(>=6)
        /// Executes the current asynchronous unit of work and returns an AnyCancellable token to cancel the subscription
        @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
        public func subscribe(
            executorPreference taskExecutor: (any TaskExecutor)?, priority: TaskPriority? = nil
        ) -> AnyCancellable {
            defer { run(executorPreference: taskExecutor, priority: priority) }
            return AnyCancellable(self)
        }
    #endif
}

extension AsyncSequence where Self: Sendable {
    /// Starts processing the elements of this async sequence, handling output and completion events,
    /// and returns an `AnyCancellable` token that can be used to cancel the subscription.
    ///
    /// This method allows you to asynchronously receive each element emitted by the sequence and respond
    /// to completion or failure. The stream runs until all elements are consumed, an error occurs,
    /// or cancellation is triggered via the returned token.
    ///
    /// - Parameters:
    ///   - receiveCompletion: An optional async closure invoked when the sequence completes, either normally with `.finished`
    ///                        or with an error `.failure`. Called exactly once.
    ///   - receiveOutput: An optional async throwing closure invoked for each element produced by the sequence.
    ///                    If this closure throws an error, the sequence is terminated and completion closure is called with `.failure`.
    ///
    /// - Returns: An `AnyCancellable` token that can be stored and used to cancel the ongoing subscription.
    ///
    /// Usage example:
    /// ```swift
    /// let publisher: AsyncStream<Int> = AsyncStream { continuation in
    ///     Task {
    ///         for i in 1...5 {
    ///             continuation.yield(i)
    ///             try await Task.sleep(nanoseconds: 500_000_000)
    ///         }
    ///         continuation.finish()
    ///     }
    /// }
    ///
    /// let cancellable = publisher.sink(
    ///     receiveCompletion: { completion in
    ///         switch completion {
    ///         case .finished:
    ///             print("Stream completed successfully")
    ///         case .failure(let error):
    ///             print("Stream failed with error: \(error)")
    ///         }
    ///     },
    ///     receiveOutput: { value in
    ///         print("Received value: \(value)")
    ///     }
    /// )
    ///
    /// // To cancel early:
    /// // cancellable.cancel()
    /// ```
    public func sink(
        receiveCompletion: (@Sendable (AsyncSequences.Completion<Error>) async -> Void)? = nil,
        receiveOutput: (@Sendable (Element) async throws -> Void)? = nil
    ) -> AnyCancellable {
        DeferredTask {
            do {
                for try await output in self {
                    try await receiveOutput?(output)
                }
                await receiveCompletion?(.finished)
            } catch {
                await receiveCompletion?(.failure(error))
            }
        }
        .subscribe()
    }
}

extension AsyncSequences {
    /// A type that represents the completion of a sequence, either due to a normal completion or an error.
    ///
    /// - `finished`: Indicates that the sequence completed normally without errors.
    /// - `failure`: Indicates that the sequence terminated with the specified error.
    public enum Completion<Failure: Error> {
        /// The sequence finished normally.
        case finished
        /// The sequence completed due to the indicated error.
        case failure(Failure)
    }
}
