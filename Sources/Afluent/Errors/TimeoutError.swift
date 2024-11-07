//
//  TimeoutError.swift
//
//
//  Created by Annalise Mariottini on 11/7/24.
//

import Foundation

/// An error indicating a timeout has occurred.
///
/// Potentially thrown by ``AsynchronousUnitOfWork/timeout(_:customError:)`` and ``AsynchronousUnitOfWork/timeout(_:clock:tolerance:customError:)``.
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public enum TimeoutError: Swift.Error, LocalizedError {
    /// A timeout occurred, with the duration timeout.
    ///
    /// Checking two `timedOut` cases for equality does not consider the `duration`.
    case timedOut(duration: any DurationProtocol)

    /// A timeout occurred, with no specific duration.
    ///
    /// Can be used to easily check if some existential error is a ``TimeoutError/timedOut(duration:)`` error.
    public static var timedOut: Self { .timedOut(duration: Duration.zero) }

    public var errorDescription: String? {
        switch self {
            case .timedOut(let duration): return "Timed out after waiting \(duration)"
        }
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension TimeoutError: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
            case (.timedOut, .timedOut): return true
        }
    }
}
