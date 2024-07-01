//
//  SerialTaskQueueTests.swift
//
//
//  Created by Tyler Thompson on 6/30/24.
//
import Atomics
import ConcurrencyExtras
import Testing

import Afluent

struct SerialTaskQueueTests {
    @Test func serialTaskQueueSchedulesOneTaskAtATime_EvenWhenSchedulingIsConcurrent() async throws {
        await withKnownIssue(isIntermittent: true) {
            let queue = SerialTaskQueue<Int>()
            actor Test {
                var isExecuting = false

                func store(_ val: Bool) {
                    isExecuting = val
                }
            }
            let test = Test()
            let results = try await withThrowingTaskGroup(of: Int.self, returning: [Int].self) { group in
                for i in 1 ... 100 {
                    group.addTask {
                        try await queue.queue {
                            let executing = await test.isExecuting
                            #expect(executing == false)
                            await test.store(true)
                            try await Task.sleep(nanoseconds: 1)
                            await test.store(false)
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

    @Test func queueCanCancelOngoingTasks() async throws {
        try await withMainSerialExecutor {
            let sub = SingleValueSubject<Void>()
            let queue = SerialTaskQueue<Void>()
            let executed = ManagedAtomic(false)
            async let _: Void = try await queue.queue {
                try sub.send()
                try Task.checkCancellation()
                try await Task.sleep(for: .seconds(20))
                executed.store(true, ordering: .sequentiallyConsistent)
            }
            await Task.yield()
            try await sub.execute()
            queue.cancelAll()
            let actual = executed.load(ordering: .sequentiallyConsistent)
            #expect(actual == false)
        }
    }
}
