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
    /// Provides an unretained, safe to use (i.e. not implicitly unwrapped), reference to an object along with the events emitted by the operator.
    /// In the case the provided object cannot be retained successfully, the sequence will throw.
    /// - Parameters:
    ///   - obj: The object to provide an unretained reference on.
    ///   - resultSelector: A function to combine the unretained referenced on `obj` and the value of the observable sequence.
    /// - Returns: An AsynchronousUnitOfWork that contains the result of `resultSelector` being called with an unretained reference on `obj` and the values of the original sequence.
    public func withUnretained<Object: AnyObject & Sendable, Out: Sendable>(_ obj: Object, resultSelector: @escaping @Sendable (Object, Success) -> Out) -> some AsynchronousUnitOfWork<Out> {
        tryMap { [weak obj] element -> Out in
            guard let obj = obj else { throw UnretainedError.failedRetaining }
            return resultSelector(obj, element)
        }
    }
}
