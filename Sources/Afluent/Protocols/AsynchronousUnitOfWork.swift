import Atomics
import Foundation

/// Represents an asynchronous unit of work.
///
/// - Parameters:
///   - Success: The type of data the unit of work will produce if it succeeds.
/// - NOTE: All units of work have the potential of throwing an error, because they can all be canceled
public protocol AsynchronousUnitOfWork<Success>: Sendable where Success: Sendable {
    /// The type of data the unit of work will produce if it succeeds.
    associatedtype Success

    var state: TaskState<Success> { get }
    /// The result of the operation (will execute the task)
    var result: Result<Success, Error> { get async throws }

    /// Executes the task with an optional task priority.
    func run(priority: TaskPriority?)

    /// Executes the task with an optional task priority and waits for the result.
    /// - Returns: The result of the task.
    @discardableResult func execute(priority: TaskPriority?) async throws -> Success

    #if swift(>=6)
        /// Executes the task with an optional task executor and priority.
        @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
        func run(executorPreference taskExecutor: (any TaskExecutor)?, priority: TaskPriority?)

        /// Executes the task with an optional task executor and priority and waits for the result.
        /// - Returns: The result of the task.
        @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
        @discardableResult func execute(
            executorPreference taskExecutor: (any TaskExecutor)?, priority: TaskPriority?
        ) async throws -> Success
    #endif

    /// Only useful when creating operators, defines the async function that should execute when the operator executes
    @Sendable func _operation() async throws -> AsynchronousOperation<Success>

    /// Cancel the task, even if it hasn't begun yet.
    func cancel()
}

extension AsynchronousUnitOfWork {
    public var result: Result<Success, Error> {
        get async throws {
            await withTaskCancellationHandler {
                await state.createTask(priority: nil, operation: operation).result
            } onCancel: {
                cancel()
            }
        }
    }

    public func run(priority: TaskPriority? = nil) {
        state.createTask(priority: priority, operation: operation)
    }

    @discardableResult public func execute(priority: TaskPriority? = nil) async throws -> Success {
        try await withTaskCancellationHandler {
            try await state.createTask(priority: priority, operation: operation).value
        } onCancel: {
            cancel()
        }
    }

    #if swift(>=6)
        @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
        public func run(
            executorPreference taskExecutor: (any TaskExecutor)?, priority: TaskPriority? = nil
        ) {
            state.createTask(
                taskExecutor: taskExecutor,
                priority: priority,
                operation: operation)
        }

        @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
        @discardableResult public func execute(
            executorPreference taskExecutor: (any TaskExecutor)?, priority: TaskPriority? = nil
        ) async throws -> Success {
            try await withTaskCancellationHandler {
                try await state.createTask(
                    taskExecutor: taskExecutor,
                    priority: priority,
                    operation: operation
                ).value
            } onCancel: {
                cancel()
            }
        }
    #endif

    public func cancel() {
        state.cancel()
    }

    @Sendable func operation() async throws -> Success {
        try Task.checkCancellation()
        let success = try await _operation()()
        try Task.checkCancellation()
        return success
    }
}

/// Reference to an operation that an operator would execute
public actor AsynchronousOperation<Success: Sendable> {
    private let operation: @Sendable () async throws -> Success
    public init(operation: @Sendable @escaping () async throws -> Success) {
        self.operation = operation
    }

    func callAsFunction() async throws -> Success {
        try await operation()
    }
}

public final class TaskState<Success: Sendable>: @unchecked Sendable {
    private let lock = NSRecursiveLock()
    private var tasks = [Task<Success, Error>]()

    private let _isCancelled = ManagedAtomic<Bool>(false)

    var isCancelled: Bool {
        _isCancelled.load(ordering: .sequentiallyConsistent)
    }

    public init() {}

    #if swift(>=6)
        @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
        @discardableResult func createTask(
            taskExecutor: (any TaskExecutor)?,
            priority: TaskPriority?,
            operation: @Sendable @escaping () async throws -> Success
        ) -> Task<Success, Error> {
            guard !isCancelled else {
                let task = Task<Success, Error> { throw CancellationError() }
                task.cancel()
                return task
            }
            let task = Task(executorPreference: taskExecutor, priority: priority) {
                try await operation()
            }
            lock.protect {
                tasks.append(task)
            }
            return task
        }
    #endif

    @discardableResult func createTask(
        priority: TaskPriority?,
        operation: @Sendable @escaping () async throws -> Success
    ) -> Task<Success, Error> {
        guard !isCancelled else {
            let task = Task<Success, Error> { throw CancellationError() }
            task.cancel()
            return task
        }
        let task = Task(priority: priority) { try await operation() }
        lock.protect {
            tasks.append(task)
        }
        return task
    }

    func cancel() {
        guard !isCancelled else { return }
        _isCancelled.store(true, ordering: .sequentiallyConsistent)
        lock.protect {
            tasks.forEach { $0.cancel() }
        }
    }
}
