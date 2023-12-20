//
//  Assign.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Foundation

extension AsynchronousUnitOfWork {
    /// Assigns the output of an asynchronous unit of work to a key path on an object.
    ///  - Parameter keyPath: The key path to assign the output to.
    ///  - Parameter object: The object to assign the output to.
    ///  - Note: This method will not retain the object passed in. If the object is deallocated the assignment will stop.
    public func assign<Root: AnyObject>(to keyPath: ReferenceWritableKeyPath<Root, Success>, on object: Root) async throws {
        _ = try await handleEvents(receiveOutput: { [weak object] in
            object?[keyPath: keyPath] = $0
        }).execute()
    }
}
