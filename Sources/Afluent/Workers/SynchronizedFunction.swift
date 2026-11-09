//
//  SynchronizedFunction.swift
//  Afluent
//

import Foundation

/// A function whose calls run one at a time, behind a lock.
///
/// Decode and Encode keep their decoder or encoder in one. It is generic over the function's
/// input and output only, which are `Sendable`, so a sendable closure that calls it captures no
/// decoder or encoder metatype.
final class SynchronizedFunction<Input, Output>: @unchecked Sendable {
    private let lock = NSRecursiveLock()
    private let body: (Input) throws -> Output

    init(_ body: @escaping (Input) throws -> Output) {
        self.body = body
    }

    func callAsFunction(_ input: Input) throws -> Output {
        try lock.protect {
            try body(input)
        }
    }
}
