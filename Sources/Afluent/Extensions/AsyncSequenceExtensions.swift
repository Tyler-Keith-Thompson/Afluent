//
//  AsyncSequenceExtensions.swift
//
//
//  Created by Tyler Thompson on 12/1/23.
//

import Foundation

extension AsyncSequence {
    /// Returns the first element of the sequence
    @_disfavoredOverload public func first() async rethrows -> Self.Element? {
        try await first { _ in true }
    }
}
