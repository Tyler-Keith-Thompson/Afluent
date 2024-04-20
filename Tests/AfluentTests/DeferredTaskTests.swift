import Testing
@testable import Afluent

struct AfluentTests {
    @Test func deferredTaskDoesNotExecuteImmediately() async throws {
        actor Test {
            var fired = false
            func fire() { fired = true }
        }
        let test = Test()

        _ = DeferredTask {
            await test.fire()
        }

        try await Task.sleep(for: .milliseconds(1))
        let fired = await test.fired

        #expect(!fired)
    }

    @Test func deferredTaskExecutesWhenAskedTo() async throws {
        await withCheckedContinuation { continuation in
            DeferredTask {
                continuation.resume()
            }.run()
        }
    }
}
