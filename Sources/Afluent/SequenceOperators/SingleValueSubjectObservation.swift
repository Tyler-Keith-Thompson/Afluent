//
//  SingleValueSubjectObservation.swift
//  Afluent
//

import Foundation

/// The value a ``SingleValueSubject`` is sent, as a sequence of one element that listens without
/// owning the subject.
///
/// Unlike `toAsyncSequence()`, which waits through the subject's `operation()`, ending or
/// cancelling iteration ends only this wait and leaves the subject pending for its other awaiters.
struct SingleValueSubjectObservation<Success: Sendable>: AsyncSequence, Sendable {
    typealias Element = Success
    let subject: SingleValueSubject<Success>

    struct AsyncIterator: AsyncIteratorProtocol {
        let subject: SingleValueSubject<Success>
        var finished = false

        mutating func next() async throws -> Success? {
            guard !finished else { return nil }
            finished = true
            return try await subject.observe()
        }
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(subject: subject)
    }
}
