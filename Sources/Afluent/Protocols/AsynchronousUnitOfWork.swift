import Foundation
import Atomics

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
    func run() throws
    
    /// Executes the task and waits for the result.
    /// - Returns: The result of the task.
    @discardableResult func execute() async throws -> Success
    
    /// Cancel the task, even if it hasn't begun yet.
    func cancel()
}

extension AsynchronousUnitOfWork {
    public var result: Result<Success, Error> {
        get async throws {
            guard !state.isCancelled else { throw CancellationError() }
            return await state.createTask().result
        }
    }
    
    public func run() throws {
        guard !state.isCancelled else { throw CancellationError() }
        state.createTask()
    }
    
    @discardableResult public func execute() async throws -> Success {
        try await result.get()
    }
    
    public func cancel() {
        state.cancel()
    }
    
    var operation: @Sendable () async throws -> Success {
        state.createOperation()
    }
}

public final class TaskState<Success: Sendable>: @unchecked Sendable {
    let lock = NSRecursiveLock()
    var tasks = [Task<Success, Error>]()
    var lazyTask: Task<Success, Error>?
    var operation: @Sendable () async throws -> Success
    
    private let _isCancelled = ManagedAtomic<Bool>(false)
    
    var isCancelled: Bool {
        _isCancelled.load(ordering: .sequentiallyConsistent)
    }
    
    init(operation: @Sendable @escaping () async throws -> Success) {
        self.operation = operation
    }
    
    static func unsafeCreation() -> TaskState<Success> {
        TaskState<Success>()
    }
    
    private init() {
        self.operation = { fatalError("Runtime contract violated, task state never set up") }
    }
    
    func setOperation(operation: @Sendable @escaping () async throws -> Success) {
        lock.lock()
        self.operation = operation
        lock.unlock()
    }
    
    func createOperation() -> @Sendable () async throws -> Success {
        lock.lock()
        if let lazyTask {
            lock.unlock()
            return { 
                try Task.checkCancellation()
                let success = try await lazyTask.value
                try Task.checkCancellation()
                return success
            }
        }
        lock.unlock()
        return { [operation] in
            try Task.checkCancellation()
            let success = try await operation()
            try Task.checkCancellation()
            return success
        }
    }
    
    func setLazyTask() -> Task<Success, Error> {
        let task = createTask()
        lock.lock()
        lazyTask = task
        lock.unlock()
        return task
    }
    
    @discardableResult func createTask() -> Task<Success, Error> {
        lock.lock()
        if let lazyTask {
            lock.unlock()
            return lazyTask
        }
        lock.unlock()
        let task = Task { try await operation() }
        lock.lock()
        tasks.append(task)
        lock.unlock()
        return task
    }
    
    func cancel() {
        guard !isCancelled else { return }
        _isCancelled.store(true, ordering: .sequentiallyConsistent)
        lock.lock()
        tasks.forEach { $0.cancel() }
        lock.unlock()
    }
}
