//
//  SerialTaskQueueTests.swift
//
//
//  Created by Tyler Thompson on 6/30/24.
//
import Afluent
import Atomics
import Testing

struct SerialTaskQueueTests {
    @Test func serialTaskQueueSchedulesOneTaskAtATime_EvenWhenSchedulingIsConcurrent() async throws {
        let isExecuting = ManagedAtomic(false)
        let queue = SerialTaskQueue<Int>()
        let clock = SuspendingClock()
        let results = try await withThrowingTaskGroup(of: Int.self, returning: [Int].self) { group in
            for i in 1 ... 100 {
                group.addTask {
                    try await queue.queue {
                        let executing = isExecuting.load(ordering: .sequentiallyConsistent)
                        #expect(!executing)
                        isExecuting.store(true, ordering: .sequentiallyConsistent)
                        try await clock.sleep(until: clock.now.advanced(by: .nanoseconds(1)))
                        isExecuting.store(false, ordering: .sequentiallyConsistent)
                        return i
                    }
                }
            }

            var results = [Int]()
            for try await result in group {
                results.append(result)
            }
            return results
        }
        // Why sort the results? Because task groups don't make any guarantees, just because I asked it to schedule these in order doesn't mean it did.
        #expect(results.sorted() == Array(1 ... 100))
    }
}
