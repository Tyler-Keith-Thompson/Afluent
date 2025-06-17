//
//  ErrorExtensions.swift
//  Afluent
//
//  Created by Tyler Thompson on 9/19/24.
//

extension Error {
    @discardableResult func throwIf<E: Error & Equatable>(not error: E) throws -> E {
        if let unwrappedError = (self as? E) {
            if unwrappedError != error {
                throw unwrappedError
            }
            return unwrappedError
        } else {
            throw self
        }
    }
    
    @discardableResult func throwIf<E: Error>(not error: E.Type) throws -> E {
        if let unwrappedError = (self as? E) {
            return unwrappedError
        } else {
            throw self
        }
    }

    @discardableResult func throwIf<E: Error & Equatable>(_ error: E) throws -> Self {
        if let unwrappedError = (self as? E) {
            if unwrappedError == error {
                throw unwrappedError
            }
        }
        return self
    }

    @discardableResult func throwIf<E: Error>(_ error: E.Type) throws -> Self {
        if let unwrappedError = (self as? E) {
            throw unwrappedError
        }
        return self
    }
}
