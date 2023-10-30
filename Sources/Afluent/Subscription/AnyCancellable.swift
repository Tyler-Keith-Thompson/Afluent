//
//  AnyCancellable.swift
//
//
//  Created by Tyler Thompson on 10/30/23.
//

import Foundation

/// Stores an erased unit of work and provides a mechanism to cancel it
/// - NOTE: The unit of work will be cancelled when the AnyCancellable is deinitialized
public final class AnyCancellable: Hashable {
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
    
    /// Cancels the asynchronous unit of work
    public func cancel() {
        unitOfWork.cancel()
    }
    
    /// Stores this type-erasing cancellable instance in the specified collection.
    public func store(in collection: inout some RangeReplaceableCollection<AnyCancellable>) {
        collection.append(self)
    }
    
    /// Stores this type-erasing cancellable instance in the specified set.
    public func store(in set: inout Set<AnyCancellable>) {
        set.insert(self)
    }
}

extension AsynchronousUnitOfWork {
    /// Executes the current asynchronous unit of work and returns an AnyCancellable token to cancel the subscription
    public func subscribe() -> AnyCancellable {
        defer { try? run() }
        return AnyCancellable(self)
    }
}
