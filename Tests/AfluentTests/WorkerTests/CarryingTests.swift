import Afluent
import Atomics
import Foundation
import Testing

// Plain `import Afluent`: these tests use carrying(_:) as a module outside Afluent would, with no
// access to the conformance SPI.
@Suite(.timeLimit(.minutes(1)))
struct CarryingTests {
    @Test func aCarryingUnitOfWorkComposesWithAnOperatorAndKeepsItsValue() async throws {
        let expectedResult: String = "42"
        let expectedValue: [String] = ["dropped 1"]
        let sut = DeferredTask { 42 }.carrying(expectedValue)

        let actual = try await sut.map { String($0) }.execute()

        #expect(actual == expectedResult)
        #expect(sut.value == expectedValue)
    }

    @Test func theCarriedValueIsThereBeforeTheWorkRuns() async throws {
        let runs = ManagedAtomic(0)
        let expectedValue: Int = 3
        let expectedRuns: Int = 0

        let sut = DeferredTask {
            runs.wrappingIncrement(ordering: .relaxed)
        }
        .carrying(expectedValue)

        #expect(sut.value == expectedValue)
        #expect(runs.load(ordering: .relaxed) == expectedRuns)
    }

    @Test func executingACarryingUnitOfWorkReturnsItsUpstreamsValue() async throws {
        let expected: Int = 7
        let sut = DeferredTask { 7 }.carrying("context")

        let actual = try await sut.execute()

        #expect(actual == expected)
    }

    @Test func aCarryingUnitOfWorkReportsItsUpstreamsErrorAsItsResult() async throws {
        struct Failure: Error {}
        let sut = DeferredTask<Int> { throw Failure() }.carrying("context")

        let actual = try await sut.result

        #expect(throws: Failure.self) { try actual.get() }
    }

    @Test func cancellingACarryingUnitOfWorkCancelsItsUpstream() async throws {
        let runs = ManagedAtomic(0)
        let expectedRuns: Int = 0
        let upstream = DeferredTask {
            runs.wrappingIncrement(ordering: .relaxed)
        }
        let sut = upstream.carrying("context")

        sut.cancel()

        await #expect(throws: CancellationError.self) { try await upstream.execute() }
        #expect(runs.load(ordering: .relaxed) == expectedRuns)
    }

    @Test func aCarryingUnitOfWorkUsesItsUpstreamsOwnExecuteSoASharedUpstreamRunsOnce() async throws {
        let runs = ManagedAtomic(0)
        let expectedRuns: Int = 1
        let sut = DeferredTask {
            runs.wrappingIncrement(ordering: .relaxed)
        }
        .share()
        .carrying("context")

        try await sut.execute()
        try await sut.execute()

        #expect(runs.load(ordering: .relaxed) == expectedRuns)
    }

    @Test func runningACarryingUnitOfWorkRunsItsUpstream() async throws {
        let ran = SingleValueSubject<Void>()
        let sut = DeferredTask { try ran.send() }.carrying("context")

        sut.run()

        try await ran.execute()
    }

    @Test func theDocumentationExampleCarriesProgressBesideAnUpload() async throws {
        let (progress, continuation) = AsyncStream<Double>.makeStream()
        let expectedStatus: String = "201"
        let expectedProgress: [Double] = [1]
        let sut = DeferredTask {
            continuation.yield(1)
            continuation.finish()
            return 201
        }
        .carrying(progress)

        let actual = try await sut.map(String.init).execute()
        var fractions: [Double] = []
        for await fraction in sut.value { fractions.append(fraction) }

        #expect(actual == expectedStatus)
        #expect(fractions == expectedProgress)
    }
}
