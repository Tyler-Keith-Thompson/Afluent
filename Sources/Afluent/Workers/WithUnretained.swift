//
//  WithUnretained.swift
//
//
//  Created by Daniel Bachar on 11/8/23.
//

import Foundation

public enum UnretainedError: Error, Equatable {
    case failedRetaining
}

// Heavily based on the RxSwift operator - `withUnretained`.
// https://github.com/ReactiveX/RxSwift/blob/main/RxSwift/Observables/WithUnretained.swift
extension AsynchronousUnitOfWork {
    /// Combines this unit of work's value with an unretained reference to the given object, or throws if the object has been deallocated.
    ///
    /// Use this operator to safely pass both a value and an object into a closure, without retaining the object.
    ///
    /// ## Example
    /// ```
    /// final class MyController: Sendable {}
    /// let controller = MyController()
    /// let combined = DeferredTask { 42 }
    ///     .withUnretained(controller) { ctrl, value in (ctrl, value) }
    /// let result = try await combined.execute()
    /// // 'result' is a tuple of (controller, 42) if controller is still alive
    /// ```
    ///
    /// - Parameters:
    ///   - obj: The object to provide as an unretained reference.
    ///   - resultSelector: Closure combining the object and the value.
    /// - Returns: An `AsynchronousUnitOfWork` containing the result of `resultSelector`, or failing if `obj` is nil.
    public func withUnretained<Object: AnyObject & Sendable, Out: Sendable>(
        _ obj: Object, resultSelector: @Sendable @escaping (Object, Success) -> Out
    ) -> some AsynchronousUnitOfWork<Out> {
        tryMap { [weak obj] element -> Out in
            guard let obj = obj else { throw UnretainedError.failedRetaining }
            return resultSelector(obj, element)
        }
    }
}
