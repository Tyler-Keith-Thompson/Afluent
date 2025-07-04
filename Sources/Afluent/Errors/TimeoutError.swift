//
//  TimeoutError.swift
//
//
//  Created by Annalise Mariottini on 11/7/24.
//

import Foundation

/// An error indicating a timeout has occurred during asynchronous work.
///
/// This error can be thrown from operations that support timeouts, such as ``AsynchronousUnitOfWork/timeout(_:customError:)`` and ``AsynchronousUnitOfWork/timeout(_:clock:tolerance:customError:)``.
///
/// You can compare two `TimeoutError` values for equality, but the associated `duration` is not considered—only the fact that a timeout occurred.
///
/// ## Example
///
/// ```swift
/// let work = DeferredTask {
///     try await Task.sleep(for: .seconds(2))
/// }
/// .timeout(.seconds(1), customError: TimeoutError.timedOut)
///
/// do {
///     try await work.execute()
/// } catch is TimeoutError {
///     print("Operation timed out")
/// }
/// ```
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public enum TimeoutError: Swift.Error, LocalizedError {
    /// A timeout occurred, with the given duration.
    ///
    /// - Parameter duration: The maximum allowed duration before timing out.
    /// - Note: Equality checks ignore the duration value.
    case timedOut(duration: any DurationProtocol)

    /// A convenient static value representing a timeout, with no specific duration.
    ///
    /// Useful for pattern-matching or as a default error for custom timeouts.
    public static var timedOut: Self { .timedOut(duration: Duration.zero) }

    public var errorDescription: String? {
        switch self {
            case .timedOut(let duration): return "Timed out after waiting \(duration)"
        }
    }
}

/// `TimeoutError` conforms to `Equatable`.
///
/// Two `TimeoutError` values are considered equal if both are `.timedOut`, regardless of their `duration` values.
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension TimeoutError: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
            case (.timedOut, .timedOut): return true
        }
    }
}
