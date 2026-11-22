import Afluent
import Benchmark
import Synchronization

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration.metrics = [.wallClock, .mallocCountTotal]
    Benchmark.defaultConfiguration.maxDuration = .seconds(2)

    let count = 1_000

    // MARK: DeferredTask: a unit of work and two operators, executed.

    // The hand-written form the library must keep pace with: the same work as async calls.
    Benchmark("DeferredTask: BASELINE async calls") { benchmark in
        for _ in benchmark.scaledIterations {
            for value in 0 ..< count {
                let produced = await produce(value)
                blackHole(produced &+ 1 &* 2)
            }
        }
    }

    Benchmark("DeferredTask: map.map.execute") { benchmark in
        for _ in benchmark.scaledIterations {
            for value in 0 ..< count {
                let result = try await DeferredTask { await produce(value) }
                    .map { $0 &+ 1 }
                    .map { $0 &* 2 }
                    .execute()
                blackHole(result)
            }
        }
    }

    // MARK: AsyncSequence: every element of a stream gathered into one array.

    Benchmark("collect: BASELINE for-await append") { benchmark in
        for _ in benchmark.scaledIterations {
            var collected = [Int]()
            for await element in stream(of: count) {
                collected.append(element)
            }
            blackHole(collected)
        }
    }

    Benchmark("collect: AsyncSequence.collect") { benchmark in
        for _ in benchmark.scaledIterations {
            for try await collected in stream(of: count).collect() {
                blackHole(collected)
            }
        }
    }

    // MARK: batch: a stream's elements gathered into arrays of a fixed size.

    let batchSize = 10

    // The hand-written form: a for-await loop that appends and emits each full array.
    Benchmark("batch: BASELINE for-await chunking") { benchmark in
        for _ in benchmark.scaledIterations {
            var pending = [Int]()
            for await element in stream(of: count) {
                pending.append(element)
                if pending.count == batchSize {
                    blackHole(pending)
                    pending = []
                }
            }
            if !pending.isEmpty { blackHole(pending) }
        }
    }

    Benchmark("batch: count") { benchmark in
        for _ in benchmark.scaledIterations {
            for try await batch in stream(of: count).batch(strategy: .count(batchSize)) {
                blackHole(batch)
            }
        }
    }

    // A timer that never fires in the run, so only its arming and resets are measured.
    Benchmark("batch: either count or time") { benchmark in
        for _ in benchmark.scaledIterations {
            let strategy = BatchStrategy.either(
                .count(batchSize), .time(interval: .seconds(60), clock: ContinuousClock()))
            for try await batch in stream(of: count).batch(strategy: strategy) {
                blackHole(batch)
            }
        }
    }

    // MARK: SerialTaskQueue: work run one at a time, in order.

    Benchmark("SerialTaskQueue: BASELINE actor calls") { benchmark in
        let counter = Counter()
        for _ in benchmark.scaledIterations {
            for value in 0 ..< count {
                blackHole(await counter.add(value))
            }
        }
    }

    Benchmark("SerialTaskQueue: enqueue") { benchmark in
        let queue = SerialTaskQueue()
        for _ in benchmark.scaledIterations {
            for value in 0 ..< count {
                blackHole(try await queue.enqueue { value &+ 1 })
            }
        }
    }

    // MARK: PassthroughSubject: every value sent reaches each subscriber.

    // Every subscriber must see every value, so a change that drops values fails instead of
    // looking faster.
    let expectedTotal = count * (count - 1) / 2
    @Sendable func check(_ total: Int) throws {
        guard total == expectedTotal else { throw MissingValues(total: total, expected: expectedTotal) }
        blackHole(total)
    }

    for subscribers in [1, 8] {
        // The hand-written form: one AsyncStream per subscriber, each value yielded to every one.
        Benchmark("PassthroughSubject \(subscribers): BASELINE AsyncStream per subscriber") { benchmark in
            for _ in benchmark.scaledIterations {
                let streams = (0 ..< subscribers).map { _ in AsyncStream<Int>.makeStream() }
                try await withThrowingTaskGroup(of: Int.self) { group in
                    for (stream, _) in streams {
                        group.addTask { await sum(of: stream) }
                    }
                    for value in 0 ..< count {
                        for (_, continuation) in streams {
                            continuation.yield(value)
                        }
                    }
                    for (_, continuation) in streams {
                        continuation.finish()
                    }
                    for try await total in group {
                        try check(total)
                    }
                }
            }
        }

        Benchmark("PassthroughSubject \(subscribers): send") { benchmark in
            for _ in benchmark.scaledIterations {
                let subject = PassthroughSubject<Int>()
                let (subscribed, subscribedContinuation) = AsyncStream<Void>.makeStream()
                try await withThrowingTaskGroup(of: Int.self) { group in
                    for _ in 0 ..< subscribers {
                        group.addTask {
                            let values = subject.handleEvents(receiveMakeIterator: {
                                subscribedContinuation.yield()
                            })
                            return try await sum(of: values)
                        }
                    }
                    // A subject drops values sent before a subscriber exists, so wait for all of them.
                    var ready = 0
                    for await _ in subscribed {
                        ready += 1
                        if ready == subscribers { break }
                    }
                    for value in 0 ..< count {
                        subject.send(value)
                    }
                    subject.send(completion: .finished)
                    for try await total in group {
                        try check(total)
                    }
                }
            }
        }
    }

    // MARK: CurrentValueSubject: the current value set, then read back.

    Benchmark("CurrentValueSubject.value: BASELINE Mutex") { benchmark in
        let current = Mutex(0)
        for _ in benchmark.scaledIterations {
            for value in 0 ..< count {
                current.withLock { $0 = value }
                blackHole(current.withLock { $0 })
            }
        }
    }

    Benchmark("CurrentValueSubject.value: set and get") { benchmark in
        let subject = CurrentValueSubject(0)
        for _ in benchmark.scaledIterations {
            for value in 0 ..< count {
                subject.value = value
                blackHole(subject.value)
            }
        }
    }

    // MARK: retry on a unit of work: work that succeeds, so only the operator's overhead is measured.

    Benchmark("DeferredTask.retry: BASELINE async calls") { benchmark in
        for _ in benchmark.scaledIterations {
            for value in 0 ..< count {
                blackHole(await produce(value))
            }
        }
    }

    Benchmark("DeferredTask.retry: retry.execute") { benchmark in
        for _ in benchmark.scaledIterations {
            for value in 0 ..< count {
                blackHole(try await DeferredTask { await produce(value) }.retry().execute())
            }
        }
    }

    // MARK: retry on a sequence: a stream that never fails, iterated through the operator.

    Benchmark("AsyncSequence.retry: BASELINE for-await") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(await sum(of: stream(of: count)))
        }
    }

    Benchmark("AsyncSequence.retry: for-await") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(try await sum(of: stream(of: count).retry()))
        }
    }

    // MARK: timeout on a sequence: a stream that never goes quiet, iterated through the idle timer.

    Benchmark("AsyncSequence.timeout: BASELINE for-await") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(await sum(of: stream(of: count)))
        }
    }

    Benchmark("AsyncSequence.timeout: for-await") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(try await sum(of: stream(of: count).timeout(.seconds(60))))
        }
    }

    // MARK: retry on a sequence: a run of consecutive failures before one element.

    // The hand-written form: a loop that makes a fresh iterator after each failure.
    Benchmark("AsyncSequence.retry failures: BASELINE loop") { benchmark in
        for _ in benchmark.scaledIterations {
            let upstream = FailsThenYields(failures: count)
            var element: Int?
            while element == nil {
                var iterator = upstream.makeAsyncIterator()
                element = try? await iterator.next()
            }
            blackHole(element)
        }
    }

    Benchmark("AsyncSequence.retry failures: for-await") { benchmark in
        for _ in benchmark.scaledIterations {
            // The one element is the index of the attempt that succeeded.
            let total = try await sum(of: FailsThenYields(failures: count).retry(UInt(count)))
            guard total == count else { throw MissingValues(total: total, expected: count) }
            blackHole(total)
        }
    }

    // MARK: eraseToAnyAsyncSequence: a stream iterated through the type-erased wrapper.

    Benchmark("eraseToAnyAsyncSequence: BASELINE for-await") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(await sum(of: stream(of: count)))
        }
    }

    Benchmark("eraseToAnyAsyncSequence: for-await") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(try await sum(of: stream(of: count).eraseToAnyAsyncSequence()))
        }
    }

    // MARK: SingleValueSubject: one value handed from a sender to a waiter.

    // The hand-written form: a value handed over through a checked continuation.
    Benchmark("SingleValueSubject: BASELINE checked continuation") { benchmark in
        for _ in benchmark.scaledIterations {
            for value in 0 ..< count {
                blackHole(await withCheckedContinuation { $0.resume(returning: value) })
            }
        }
    }

    Benchmark("SingleValueSubject: send then execute") { benchmark in
        for _ in benchmark.scaledIterations {
            for value in 0 ..< count {
                let subject = SingleValueSubject<Int>()
                try subject.send(value)
                blackHole(try await subject.execute())
            }
        }
    }
}

@inline(never)
func produce(_ value: Int) async -> Int {
    value
}

func stream(of count: Int) -> AsyncStream<Int> {
    AsyncStream { continuation in
        for element in 0 ..< count {
            continuation.yield(element)
        }
        continuation.finish()
    }
}

actor Counter {
    private var total = 0

    func add(_ value: Int) -> Int {
        total &+= value
        return total
    }
}

func sum<S: AsyncSequence>(of values: S) async rethrows -> Int where S.Element == Int {
    var total = 0
    for try await value in values {
        total &+= value
    }
    return total
}

struct MissingValues: Error {
    let total: Int
    let expected: Int
}

/// Throws on each of its first `failures` iterations, then yields one element.
final class FailsThenYields: AsyncSequence, Sendable {
    struct Refused: Error {}

    let failures: Int
    let attempts = Mutex(0)

    init(failures: Int) {
        self.failures = failures
    }

    struct AsyncIterator: AsyncIteratorProtocol {
        let sequence: FailsThenYields
        var finished = false

        mutating func next() async throws -> Int? {
            guard !finished else { return nil }
            let attempt = sequence.attempts.withLock { attempts in
                defer { attempts += 1 }
                return attempts
            }
            if attempt < sequence.failures { throw Refused() }
            finished = true
            return attempt
        }
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(sequence: self)
    }
}
