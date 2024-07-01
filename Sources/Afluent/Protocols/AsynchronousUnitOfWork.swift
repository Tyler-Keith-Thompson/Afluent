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

    /// Executes the task
    func run()

    /// Executes the task and waits for the result.
    /// - Returns: The result of the task.
    @discardableResult func execute() async throws -> Success

    /// Only useful when creating operators, defines the async function that should execute when the operator executes
    @Sendable func _operation() async throws -> AsynchronousOperation<Success>

    /// Cancel the task, even if it hasn't begun yet.
    func cancel()
}

extension AsynchronousUnitOfWork {
    public var result: Result<Success, Error> {
        get async throws {
            await withTaskCancellationHandler {
                return await state.createTask(operation: operation).result
            } onCancel: {
                cancel()
            }
        }
    }

    public func run() {
        state.createTask(operation: operation)
    }

    @discardableResult public func execute() async throws -> Success {
        try await result.get()
    }

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

    public init() { }

    @discardableResult func createTask(operation: @Sendable @escaping () async throws -> Success) -> Task<Success, Error> {
        guard !isCancelled else {
            let task = Task<Success, Error> { throw CancellationError() }
            task.cancel()
            return task
        }
        let task = Task { try await operation() }
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
