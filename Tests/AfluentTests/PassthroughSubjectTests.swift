//
//  PassthroughSubjectTests.swift
//  Afluent
//
//  Created by Tyler Thompson on 10/12/24.
//

import Afluent
import Testing

struct PassthroughSubjectTests {
    @Test func passthroughSubjectCanSendValuesAndFinish() async throws {
        actor Test {
            var values = [Int]()
            func appendValue(_ value: Int) {
                values.append(value)
            }
        }
        let test = Test()
        let subject = PassthroughSubject<Int>()
        let taskStartedSubject = SingleValueSubject<Void>()

        let task = Task {
            for try await value in subject.handleEvents(receiveNext: {
                try? taskStartedSubject.send()
            }) {
                await test.appendValue(value)
            }
        }

        try await taskStartedSubject.execute()

        #expect(await test.values.isEmpty)

        subject.send(1)
        subject.send(2)
        subject.send(3)
        subject.send(completion: .finished)

        _ = try await task.value

        let val = await test.values
        print(val)

        #expect(await test.values == [1, 2, 3])
    }

    @Test func passthroughSubjectCanSendValues_ToMultipleConsumers_AndFinish() async throws {
        actor Test {
            var values = [Int]()
            func appendValue(_ value: Int) {
                values.append(value)
            }
        }
        let test = Test()
        let test2 = Test()
        let subject = PassthroughSubject<Int>()

        let taskStartedSubject = SingleValueSubject<Void>()
        let task = Task {
            for try await value in subject.handleEvents(receiveNext: {
                try? taskStartedSubject.send()
            }) {
                await test.appendValue(value)
            }
        }

        let task2StartedSubject = SingleValueSubject<Void>()
        let task2 = Task {
            for try await value in subject.handleEvents(receiveNext: {
                try? task2StartedSubject.send()
            }) {
                await test2.appendValue(value)
            }
        }

        try await taskStartedSubject.execute()
        try await task2StartedSubject.execute()

        #expect(await test.values.isEmpty)
        #expect(await test2.values.isEmpty)

        subject.send(1)
        subject.send(2)
        subject.send(3)
        subject.send(completion: .finished)

        _ = try await task.value
        _ = try await task2.value

        #expect(await test.values == [1, 2, 3])
        #expect(await test2.values == [1, 2, 3])
    }

    @Test func passthroughSubjectStopsSendingValuesUponFinish() async throws {
        actor Test {
            var values = [Int]()
            func appendValue(_ value: Int) {
                values.append(value)
            }
        }
        let test = Test()
        let subject = PassthroughSubject<Int>()
        let taskStartedSubject = SingleValueSubject<Void>()

        let task = Task {
            for try await value in subject.handleEvents(receiveNext: {
                try? taskStartedSubject.send()
            }) {
                await test.appendValue(value)
            }
        }

        try await taskStartedSubject.execute()

        #expect(await test.values.isEmpty)

        subject.send(1)
        subject.send(2)
        subject.send(3)
        subject.send(completion: .finished)

        _ = try await task.value

        let task2StartedSubject = SingleValueSubject<Void>()
        let task2 = Task {
            for try await value in subject.handleEvents(receiveNext: {
                try? task2StartedSubject.send()
            }) {
                await test.appendValue(value)
            }
        }

        try await task2StartedSubject.execute()

        subject.send(4)

        _ = try await task2.value

        #expect(await test.values == [1, 2, 3])
    }

    @Test func passthroughSubjectCanCompleteWithError() async throws {
        enum Err: Error, Equatable {
            case e1
        }

        actor Test {
            var values = [Int]()
            func appendValue(_ value: Int) {
                values.append(value)
            }
        }
        let test = Test()
        let subject = PassthroughSubject<Int>()
        let taskStartedSubject = SingleValueSubject<Void>()

        let firstValueReceived = SingleValueSubject<Void>()

        let task = Task {
            for try await value in subject.handleEvents(receiveNext: {
                try? taskStartedSubject.send()
            }) {
                try? firstValueReceived.send()
                await test.appendValue(value)
            }
        }

        try await taskStartedSubject.execute()
        #expect(await test.values.isEmpty)

        subject.send(1)
        try await firstValueReceived.execute()
        subject.send(completion: .failure(Err.e1))
        subject.send(3)
        subject.send(completion: .finished)

        let task1Result = await task.result
        try #require(throws: Err.e1, performing: { try task1Result.get() })

        let task2StartedSubject = SingleValueSubject<Void>()
        let task2 = Task {
            for try await value in subject.handleEvents(receiveNext: {
                try? task2StartedSubject.send()
            }) {
                await test.appendValue(value)
            }
        }

        try await task2StartedSubject.execute()

        subject.send(4)

        let task2Result = await task2.result
        try #require(throws: Err.e1, performing: { try task2Result.get() })

        #expect(await test.values == [1])
    }

    @Test func passthroughSubjectCanSendVoidValues() async throws {
        actor Test {
            var count = 0
            func appendValue() {
                count += 1
            }
        }
        let test = Test()
        let subject = PassthroughSubject<Void>()
        let taskStartedSubject = SingleValueSubject<Void>()

        let task = Task {
            for try await _ in subject.handleEvents(receiveNext: {
                try? taskStartedSubject.send()
            }) {
                await test.appendValue()
            }
        }

        try await taskStartedSubject.execute()

        #expect(await test.count == 0)

        subject.send()
        subject.send()
        subject.send()
        subject.send(completion: .finished)

        _ = try await task.value

        let task2StartedSubject = SingleValueSubject<Void>()
        let task2 = Task {
            for try await _ in subject.handleEvents(receiveNext: {
                try? task2StartedSubject.send()
            }) {
                await test.appendValue()
            }
        }

        try await task2StartedSubject.execute()

        subject.send()

        _ = try await task2.value

        #expect(await test.count == 3)
    }

    @Test func passthroughSubjectDiscardsValuesSentBeforeAnySubscriber() async throws {
        let subject = PassthroughSubject<Int>()
        subject.send(1)
        subject.send(2)
        subject.send(3)

        let taskStartedSubject = SingleValueSubject<Void>()
        let task = Task {
            var received = [Int]()
            for try await value in subject.handleEvents(receiveNext: {
                try? taskStartedSubject.send()
            }).prefix(2) {
                received.append(value)
            }
            return received
        }

        try await taskStartedSubject.execute()
        subject.send(4)
        subject.send(5)
        subject.send(6)

        #expect(try await task.value == [4, 5])
    }

    @Test func passthroughSubjectDoesNotReplayEarlierValuesToLateSubscribers() async throws {
        let subject = PassthroughSubject<Int>()

        let firstStarted = SingleValueSubject<Void>()
        let first = Task {
            var received = [Int]()
            for try await value in subject.handleEvents(receiveNext: {
                try? firstStarted.send()
            }) {
                received.append(value)
            }
            return received
        }
        try await firstStarted.execute()
        subject.send(1)
        subject.send(2)

        let secondStarted = SingleValueSubject<Void>()
        let second = Task {
            var received = [Int]()
            for try await value in subject.handleEvents(receiveNext: {
                try? secondStarted.send()
            }) {
                received.append(value)
            }
            return received
        }
        try await secondStarted.execute()
        subject.send(3)
        subject.send(completion: .finished)

        #expect(try await first.value == [1, 2, 3])
        #expect(try await second.value == [3])
    }

    @Test func passthroughSubjectBuffersValuesForASlowSubscriber() async throws {
        let subject = PassthroughSubject<Int>()
        let taskStartedSubject = SingleValueSubject<Void>()
        let task = Task {
            var received = [Int]()
            for try await value in subject.handleEvents(receiveNext: {
                try? taskStartedSubject.send()
            }) {
                await Task.yield()
                received.append(value)
            }
            return received
        }

        try await taskStartedSubject.execute()
        for i in 0..<100 { subject.send(i) }
        subject.send(completion: .finished)

        #expect(try await task.value == Array(0..<100))
    }

    @Test func passthroughSubjectSubscriberFinishesWhenCancelled() async throws {
        let subject = PassthroughSubject<Int>()
        let taskStartedSubject = SingleValueSubject<Void>()
        let task = Task {
            var received = [Int]()
            for try await value in subject.handleEvents(receiveNext: {
                try? taskStartedSubject.send()
            }) {
                received.append(value)
            }
            return received
        }

        try await taskStartedSubject.execute()
        task.cancel()

        // Either a clean finish or a CancellationError is acceptable; it must not hang.
        _ = await task.result
        subject.send(1)  // Must not crash or resume a stale continuation.
    }
}
