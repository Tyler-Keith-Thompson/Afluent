//
//  DiscardOutputSequence.swift
//
//
//  Created by Tyler Thompson on 12/10/23.
//

import Foundation

extension AsyncSequence where Self: Sendable {
    /// Transforms each output value from the upstream sequence into `Void`.
    ///
    /// Use this to ignore the payload of each element, but still receive an event for every value.
    ///
    /// ## Example
    /// ```
    /// for await _ in Just(1).discardOutput() {
    ///     // Loop runs once for each element, but value is always Void
    /// }
    /// ```
    public func discardOutput() -> AsyncMapSequence<Self, Void> {
        map { _ in }
    }
}
