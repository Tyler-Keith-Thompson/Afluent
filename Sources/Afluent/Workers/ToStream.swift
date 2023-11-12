//
//  ToStream.swift
//
//
//  Created by Tyler Thompson on 11/11/23.
//

import Foundation

extension AsynchronousUnitOfWork {
    public func toStream() -> AsyncThrowingStream<Success, Error> {
        .init { continuation in
            Task {
                do {
                    let val = try await operation()
                    continuation.yield(val)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
