import Afluent
import Benchmark

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
