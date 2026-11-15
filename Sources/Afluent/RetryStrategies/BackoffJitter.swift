//
//  BackoffJitter.swift
//  Afluent
//

/// How a wait is randomized, so many clients that started waiting together don't all wake together.
///
/// Jitter takes a nominal wait and picks the wait to use instead. It works on any clock's
/// `Duration`, and the operators that wait take it as a `jitter:` parameter:
/// ``ExponentialBackoffStrategy`` (each backoff delay), ``AsyncSequences/TimerSequence`` (where
/// each tick falls inside its period) and `delay` on units of work and sequences (each wait).
///
/// The kinds follow "Exponential Backoff and Jitter" (AWS Architecture Blog):
/// - ``none``: the nominal wait, exactly.
/// - ``full(using:)``: anywhere from zero up to the nominal wait.
/// - ``equal(using:)``: half the nominal wait, plus anywhere up to the other half.
/// - ``decorrelated(using:)``: at least the nominal wait, and up to three times the previous wait
///   this jitter produced, so the waits spread further apart the longer they go on.
///
/// Each random kind draws from the generator it was given, one value per wait, so a seeded
/// generator makes the waits reproducible. A jitter value holds its generator, and for
/// ``decorrelated(using:)`` the previous wait, by reference: copies of a value share them, and so
/// do the operators it is passed to. Make a new value for each operator that should have its own.
///
/// ## Example
/// ```swift
/// let backoff = ExponentialBackoffStrategy(base: 2, maxDelay: .seconds(60), jitter: .equal())
/// let heartbeat = TimerSequence.publish(every: .seconds(30), jitter: .full())
/// ```
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct BackoffJitter: Sendable {
    enum Kind: Sendable {
        case full
        case equal
        case decorrelated
    }

    struct State: Sendable {
        var generator: any RandomNumberGenerator & Sendable
        /// The last wait this jitter produced, for ``BackoffJitter/decorrelated(using:)``.
        var previous: (any DurationProtocol)?
    }

    /// `nil` for ``none``.
    let kind: Kind?
    let state: CriticalState<State>?

    init(kind: Kind, generator: some RandomNumberGenerator & Sendable) {
        self.kind = kind
        self.state = CriticalState(State(generator: generator, previous: nil))
    }

    private init() {
        kind = nil
        state = nil
    }

    /// Waits exactly the nominal wait.
    public static var none: BackoffJitter { BackoffJitter() }

    /// Waits a random duration from zero up to the nominal wait.
    ///
    /// - Parameter generator: The source of randomness. Defaults to the system's generator; pass a
    ///   seeded one to make the waits reproducible.
    /// - Returns: Jitter that spreads each wait over the whole nominal wait: a wait `d` becomes one
    ///   in `0 ..< d`.
    public static func full(
        using generator: some RandomNumberGenerator & Sendable = SystemRandomNumberGenerator()
    ) -> BackoffJitter {
        BackoffJitter(kind: .full, generator: generator)
    }

    /// Waits half the nominal wait plus a random duration up to the other half.
    ///
    /// - Parameter generator: The source of randomness. Defaults to the system's generator; pass a
    ///   seeded one to make the waits reproducible.
    /// - Returns: Jitter that spreads each wait over the upper half of the nominal wait: a wait `d`
    ///   becomes one in `d / 2 ..< d`.
    public static func equal(
        using generator: some RandomNumberGenerator & Sendable = SystemRandomNumberGenerator()
    ) -> BackoffJitter {
        BackoffJitter(kind: .equal, generator: generator)
    }

    /// Waits a random duration from the nominal wait up to three times the previous wait this
    /// jitter produced.
    ///
    /// The first wait, and any wait at least three times the previous one, is exactly the nominal
    /// wait. Each operator bounds it: ``ExponentialBackoffStrategy`` at its `maxDelay`,
    /// `delay` at three times the nominal wait, and ``AsyncSequences/TimerSequence`` at its
    /// interval, which makes a timer tick exactly on schedule. ``ExponentialBackoffStrategy/reset()``
    /// forgets the previous wait.
    ///
    /// - Parameter generator: The source of randomness. Defaults to the system's generator; pass a
    ///   seeded one to make the waits reproducible.
    /// - Returns: Jitter that turns a wait `d` into one in `d ..< max(d, 3 × previous)`, where
    ///   `previous` is the last wait it produced.
    public static func decorrelated(
        using generator: some RandomNumberGenerator & Sendable = SystemRandomNumberGenerator()
    ) -> BackoffJitter {
        BackoffJitter(kind: .decorrelated, generator: generator)
    }

    /// The wait to use in place of `delay`.
    ///
    /// Full and equal jitter never exceed `delay`; decorrelated jitter never exceeds `limit`. A
    /// `delay` of zero or less is returned unchanged.
    ///
    /// - Parameters:
    ///   - delay: The nominal wait.
    ///   - limit: The longest wait decorrelated jitter may produce; at least `delay`. Evaluated
    ///     only for decorrelated jitter.
    /// - Returns: The jittered wait.
    /// - Complexity: O(1): one draw from the generator and at most 32 halvings of `delay`.
    func jittered<D: DurationProtocol>(_ delay: D, upTo limit: @autoclosure () -> D) -> D {
        guard let kind, let state, delay > .zero else { return delay }
        return state.withCriticalRegion { state -> D in
            let draw = state.generator.next()
            switch kind {
            case .full:
                return Self.fraction(draw, of: delay)
            case .equal:
                let half = delay / 2
                return half + Self.fraction(draw, of: delay - half)
            case .decorrelated:
                let limit = max(limit(), delay)
                let ceiling: D
                if let previous = state.previous as? D {
                    ceiling = previous > limit / 3 ? limit : max(delay, previous * 3)
                } else {
                    ceiling = delay
                }
                let wait = delay + Self.fraction(draw, of: ceiling - delay)
                state.previous = wait
                return wait
            }
        }
    }

    /// Forgets the previous wait, so the next decorrelated wait starts from the nominal one.
    func reset() {
        state?.withCriticalRegion { $0.previous = nil }
    }

    /// A duration in `0 ..< duration` (zero when `duration` is zero), uniform on a grid of 2^32
    /// steps: each of `draw`'s top 32 bits, most significant first, adds the next halving of
    /// `duration`.
    ///
    /// Only halves and sums values no larger than `duration`, so it can't overflow.
    private static func fraction<D: DurationProtocol>(_ draw: UInt64, of duration: D) -> D {
        var result = D.zero
        var half = duration / 2
        var bit: UInt64 = 1 << 63
        while half > .zero, bit > 1 << 31 {
            if draw & bit != 0 { result += half }
            half = half / 2
            bit >>= 1
        }
        return result
    }
}
