import Atomics
import Foundation

/// Represents an asynchronous unit of work.
///
/// Types such as `DeferredTask` and asynchronous operators conform to this protocol.
///
/// You can use protocol-oriented code to compose, run, and cancel asynchronous work in a consistent way.
///
/// All units of work have the potential to throw an error (including cancellation).
///
/// - Parameters:
///   - Success: The type of data the unit of work will produce if it succeeds.
///
/// ## Example
///
/// ```swift
/// // Chain multiple operators to transform and control asynchronous work
/// let work: some AsynchronousUnitOfWork<Int> = DeferredTask {
///     21
/// }
/// .map { $0 * 2 }
/// .timeout(.seconds(1))
///
/// // Execute and await the result (will be 42)
/// let value = try await work.execute()
/// print(value) // Prints: 42
///
/// // Cancel the work if needed
/// work.cancel()
/// ```
public protocol AsynchronousUnitOfWork<Success>: Sendable where Success: Sendable {
    /// The type of data the unit of work will produce if it succeeds.
    associatedtype Success

    var state: TaskState<Success> { get }
    
    /// Awaits and returns the result of the asynchronous unit of work.
    ///
    /// If the work is cancelled, throws `CancellationError`.
    /// If the work fails, throws the underlying error.
    /// If the work succeeds, returns the result.
    ///
    /// ## Example
    /// ```swift
    /// let work = DeferredTask { 1 + 2 }
    /// let result = try await work.result
    /// ```
    var result: Result<Success, Error> { get async throws }

    /// Starts the asynchronous unit of work with an optional priority.
    ///
    /// This is a fire-and-forget operation; use ``execute(priority:)`` to await the result.
    /// - Parameter priority: The priority to use for the task, or `nil` for default.
    ///
    /// ## Example
    /// ```swift
    /// let work = DeferredTask { 42 }
    /// work.run()
    /// ```
    func run(priority: TaskPriority?)

    /// Starts the asynchronous unit of work and awaits its result.
    ///
    /// - Parameter priority: The priority to use for the task, or `nil` for default.
    /// - Returns: The value produced if the work succeeds.
    /// - Throws: `CancellationError` if cancelled, or another error if the work fails.
    ///
    /// ## Example
    /// ```swift
    /// let work = DeferredTask { 21 * 2 }
    /// let value = try await work.execute()
    /// print(value) // Prints: 42
    /// ```
    @discardableResult func execute(priority: TaskPriority?) async throws -> Success

    #if swift(>=6)
        /// Starts the asynchronous unit of work using a specific task executor and optional priority.
        ///
        /// - Parameters:
        ///   - taskExecutor: The preferred executor for the task, or `nil` for the default.
        ///   - priority: The priority to use, or `nil` for default.
        @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
        func run(executorPreference taskExecutor: (any TaskExecutor)?, priority: TaskPriority?)

        /// Starts the asynchronous unit of work with a specific task executor and optional priority, and awaits its result.
        ///
        /// - Parameters:
        ///   - taskExecutor: The preferred executor for the task, or `nil` for the default.
        ///   - priority: The priority to use, or `nil` for default.
        /// - Returns: The value produced if the work succeeds.
        /// - Throws: `CancellationError` if cancelled, or another error if the work fails.
        @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
        @discardableResult func execute(
            executorPreference taskExecutor: (any TaskExecutor)?, priority: TaskPriority?
        ) async throws -> Success
    #endif

    /// Only useful when creating operators, defines the async function that should execute when the operator executes
    @Sendable func _operation() async throws -> AsynchronousOperation<Success>

    /// Cancels the asynchronous unit of work.
    ///
    /// If the work is already running or scheduled, it will be cancelled. If not yet started, it will not execute.
    ///
    /// ## Example
    /// ```swift
    /// let work = DeferredTask { await Task.sleep(for: .seconds(5)); return 1 }
    /// work.run()
    /// work.cancel()
    /// ```
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
