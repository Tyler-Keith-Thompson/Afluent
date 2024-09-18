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
        let queue = SerialTaskQueue()
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

    @Test func queuingATaskThatThrows_ThrowsToQueue() async throws {
        enum Err: Error {
            case e1
        }
        let queue = SerialTaskQueue()
        let result = await Task {
            try await queue.queue {
                throw Err.e1
            }
        }.result
        #expect(throws: Err.self, performing: {
            try result.get()
        })
    }

    @Test func queuingATaskThatThrows_StillAllowsOthersToBeQueued() async throws {
        enum Err: Error {
            case e1
        }
        let queue = SerialTaskQueue()
        let result = await Task {
            try await queue.queue {
                throw Err.e1
            }
        }.result
        #expect(throws: Err.self, performing: {
            try result.get()
        })
        let result2 = try await queue.queue {
            2
        }
        #expect(result2 == 2)
    }

    @Test(.disabled(if: SwiftVersion.isSwift6, "There's some kind of Xcode 16 bug where this crashes intermittently")) func queueCanCancelOngoingTasks() async throws {
        try await withMainSerialExecutor {
            let sub = SingleValueSubject<Void>()
            let queue = SerialTaskQueue()
            let executed = ManagedAtomic(false)
            async let _: Void = try await queue.queue {
                try sub.send()
                try Task.checkCancellation()
                try await Task.sleep(for: .milliseconds(20))
                executed.store(true, ordering: .sequentiallyConsistent)
            }
            await Task.yield()
            try await sub.execute()
            queue.cancelAll()
            let actual = executed.load(ordering: .sequentiallyConsistent)
            #expect(actual == false)
        }
    }

    #if swift(>=6.0)
        @Test func queueCanCancelOngoingTasks_OnDeinit() async throws {
            try await withMainSerialExecutor {
                let sub = SingleValueSubject<Void>()
                var queue: SerialTaskQueue? = SerialTaskQueue()
                let executed = ManagedAtomic(false)
                async let _: Void = try await #require(queue).queue {
                    try sub.send()
                    try Task.checkCancellation()
                    try await Task.sleep(for: .milliseconds(20))
                    executed.store(true, ordering: .sequentiallyConsistent)
                }
                await Task.yield()
                try await sub.execute()
                queue = nil
                let actual = executed.load(ordering: .sequentiallyConsistent)
                #expect(actual == false)
            }
        }
    #endif
}

enum SwiftVersion {
    static var isSwift6: Bool {
#if swift(>=6.0)
        return true
#else
        return false
#endif
    }
}
