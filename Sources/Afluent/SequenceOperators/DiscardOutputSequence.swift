//
//  DiscardOutputSequence.swift
//
//
//  Created by Tyler Thompson on 12/10/23.
//

import Foundation

extension AsyncSequence where Self: Sendable {
    /// Discards the output values from the upstream `AsyncSequence`.
    ///
    /// - Returns: An `AsyncSequence` of type `Void` that emits a completion event when the upstream completes.
    public func discardOutput() -> AsyncMapSequence<Self, Void> {
        map { _ in }
    }
}
