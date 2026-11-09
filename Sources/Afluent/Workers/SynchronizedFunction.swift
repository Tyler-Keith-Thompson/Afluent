//
//  SynchronizedFunction.swift
//  Afluent
//

/// A function whose calls run one at a time, in one critical region.
///
/// Decode and Encode keep their decoder or encoder in one, captured by the function, so neither needs to be
/// `Sendable`.
///
/// It is `@unchecked Sendable` because the function, its input and its output needn't be `Sendable`: every call runs
/// inside the region, so one thread at a time uses what the function captures. Region checking can't express a
/// non-Sendable value the caller passed in and then shares only under a lock.
final class SynchronizedFunction<Input, Output>: @unchecked Sendable {
    private let region = CriticalState(())
    private let body: (Input) throws -> Output

    init(_ body: @escaping (Input) throws -> Output) {
        self.body = body
    }

    func callAsFunction(_ input: Input) throws -> Output {
        // Set inside the region and read after it, on this thread.
        nonisolated(unsafe) var result: Result<Output, any Error>?
        region.withCriticalRegion { _ in result = Result { try body(input) } }
        // The region always runs, so the result is set.
        return try result.unsafelyUnwrapped.get()
    }
}
