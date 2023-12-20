//
//  PrintSequence.swift
//
//
//  Created by Tyler Thompson on 12/17/23.
//

import Foundation

extension AsyncSequence {
    /// Logs events from the upstream `AsyncSequence` to the console.
    ///
    /// - Parameters:
    ///   - prefix: A string to prefix each log message with. Default is an empty string.
    ///
    /// - Returns: An `AsyncSequence` that behaves identically to the upstream but logs events.
    public func print(_ prefix: String = "") -> AsyncSequences.HandleEvents<Self> {
        handleEvents {
            Swift.print("\(prefix) received output: \($0)")
        } receiveError: {
            Swift.print("\(prefix) received error: \($0)")
        } receiveComplete: {
            Swift.print("\(prefix) received completion")
        } receiveCancel: {
            Swift.print("\(prefix) received cancellation")
        }
    }
}
