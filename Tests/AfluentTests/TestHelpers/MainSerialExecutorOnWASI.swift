//
//  MainSerialExecutorOnWASI.swift
//  Afluent
//

#if os(WASI)
    // swift-concurrency-extras leaves `withMainSerialExecutor` out on WASI. There the global
    // executor already runs every job on the one thread, in the order enqueued, which is what the
    // main serial executor gives elsewhere, so the tests that use it run their body as it is rather
    // than being left out on WASI.
    @MainActor
    func withMainSerialExecutor(
        @_implicitSelfCapture operation: @isolated(any) () async throws -> Void
    ) async rethrows {
        try await operation()
    }
#endif
