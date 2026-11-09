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

    for subscribers in [1, 8] {
        // The hand-written form: one AsyncStream per subscriber, each value yielded to every one.
        Benchmark("PassthroughSubject \(subscribers): BASELINE AsyncStream per subscriber") { benchmark in
            for _ in benchmark.scaledIterations {
                let streams = (0 ..< subscribers).map { _ in AsyncStream<Int>.makeStream() }
                await withTaskGroup(of: Int.self) { group in
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
                    for await total in group {
                        blackHole(total)
                    }
                }
            }
        }

        Benchmark("PassthroughSubject \(subscribers): send") { benchmark in
            for _ in benchmark.scaledIterations {
                let subject = PassthroughSubject<Int>()
                let (subscribed, subscribedContinuation) = AsyncStream<Void>.makeStream()
                await withTaskGroup(of: Int.self) { group in
                    for _ in 0 ..< subscribers {
                        group.addTask {
                            let values = subject.handleEvents(receiveMakeIterator: {
                                subscribedContinuation.yield()
                            })
                            return (try? await sum(of: values)) ?? 0
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
                    for await total in group {
                        blackHole(total)
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
