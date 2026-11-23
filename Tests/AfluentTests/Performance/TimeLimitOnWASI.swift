//
//  TimeLimitOnWASI.swift
//  Afluent
//

// A copy of ../TestHelpers/TimeLimitOnWASI.swift: AfluentPerformanceTests builds only Performance/,
// and AfluentTests excludes Performance/, so each target needs its own.
#if os(WASI)
    import Testing

    // On WASI a pending sleep holds the one thread until it fires, so a time limit's timer stalls
    // every task the test body waits on until the limit has passed, and the test fails at its
    // limit. Here `.timeLimit(.minutes(n))` enables the test instead; `just wasi-test` bounds each
    // run itself. Its `minutes(_:)` takes an `Int` rather than `some BinaryInteger`, which makes
    // the compiler prefer it to Swift Testing's.
    struct TimeLimitOnWASI {
        static func minutes(_ minutes: Int) -> Self { Self() }
    }

    extension Trait where Self == ConditionTrait {
        static func timeLimit(_ timeLimit: TimeLimitOnWASI) -> Self {
            .enabled(if: true)
        }
    }
#endif
