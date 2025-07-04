//
//  PrintSequence.swift
//
//
//  Created by Tyler Thompson on 12/17/23.
//

import Foundation

extension AsyncSequence where Self: Sendable {
    /// Logs events from the sequence to the console, optionally with a prefix.
    ///
    /// Use this for debugging or observing the lifecycle of a sequence.
    ///
    /// - Parameter prefix: A string to prefix each log message with. Default is an empty string.
    ///
    /// ## Example
    /// ```swift
    /// for try await value in Just(1).print("MyPrefix") {
    ///     // Prints lifecycle events and value to the console with prefix "MyPrefix"
    /// }
    /// ```
    public func print(_ prefix: String = "") -> AsyncSequences.HandleEvents<Self> {
        handleEvents {
            Swift.print("\(prefix) received make iterator")
        } receiveNext: {
            Swift.print("\(prefix) received next")
        } receiveOutput: {
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
