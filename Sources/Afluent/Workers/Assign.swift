//
//  Assign.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Foundation

extension AsynchronousUnitOfWork {
    /// Assigns the output of an asynchronous unit of work to a key path on an object when the work completes successfully.
    ///
    /// This method allows you to bind the result of the asynchronous operation to a property of an object, updating that property automatically upon completion.
    /// The object is held weakly to avoid retain cycles, so if the object is deallocated before the asynchronous work completes, the assignment will not occur.
    ///
    /// ## Example
    /// ```swift
    /// class MyModel: Sendable {
    ///     var value: Int = 0
    /// }
    ///
    /// let model = MyModel()
    /// let unitOfWork: AsynchronousUnitOfWork<Int> = ...
    ///
    /// Task {
    ///     try await unitOfWork.assign(to: \.value, on: model)
    ///     print("Model value updated to \(model.value)")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - keyPath: The key path to assign the output to.
    ///   - object: The object to assign the output to.
    /// - Throws: Rethrows any error thrown by the asynchronous unit of work.
    /// - Note: This method is asynchronous and will complete when the assignment has been made or the operation fails.
    public func assign<Root: AnyObject & Sendable>(
        to keyPath: ReferenceWritableKeyPath<Root, Success>, on object: Root
    ) async throws {
        _ = try await handleEvents(receiveOutput: { [weak object] in
            object?[keyPath: keyPath] = $0
        }).execute()
    }
}
