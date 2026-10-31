//
//  CurrentValueSubjectTests.swift
//  Afluent
//
//  Created by Tyler Thompson on 10/12/24.
//

import Afluent
import Testing

struct CurrentValueSubjectTests {
    @Test func currentValueSubjectCanSendValuesAndFinish() async throws {
        actor Test {
            var values = [Int]()
            func appendValue(_ value: Int) {
                values.append(value)
            }
        }
        let test = Test()
        let subject = CurrentValueSubject<Int>(1)
        let taskStartedSubject = SingleValueSubject<Void>()

        let task = Task {
            for try await value in subject.handleEvents(receiveMakeIterator: {
                try? taskStartedSubject.send()
            }) {
                await test.appendValue(value)
            }
        }

        try await taskStartedSubject.execute()

        #expect(await test.values.count < 2)

        subject.send(2)
        subject.send(3)
        subject.send(completion: .finished)

        _ = try await task.value

        #expect(await test.values == [1, 2, 3])
    }

    @Test func currentValueSubjectUpdatesValueOnSend() async throws {
        actor Test {
            var values = [Int]()
            func appendValue(_ value: Int) {
                values.append(value)
            }
        }
        let test = Test()
        let subject = CurrentValueSubject<Int>(1)
        #expect(subject.value == 1)
        let taskStartedSubject = SingleValueSubject<Void>()

        let task = Task {
            for try await value in subject.handleEvents(receiveMakeIterator: {
                try? taskStartedSubject.send()
            }) {
                await test.appendValue(value)
            }
        }

        try await taskStartedSubject.execute()

        #expect(await test.values.count < 2)

        subject.send(2)
        #expect(subject.value == 2)
        subject.send(3)
        #expect(subject.value == 3)
        subject.send(completion: .finished)

        _ = try await task.value

        #expect(await test.values == [1, 2, 3])
    }

    @Test func currentValueSubjectSendsWhenValueUpdated() async throws {
        actor Test {
            var values = [Int]()
            func appendValue(_ value: Int) {
                values.append(value)
            }
        }
        let test = Test()
        let subject = CurrentValueSubject<Int>(1)
        #expect(subject.value == 1)
        let taskStartedSubject = SingleValueSubject<Void>()

        let task = Task {
            for try await value in subject.handleEvents(receiveMakeIterator: {
                try? taskStartedSubject.send()
            }) {
                await test.appendValue(value)
            }
        }

        try await taskStartedSubject.execute()

        #expect(await test.values.count < 2)

        subject.value = 2
        #expect(subject.value == 2)
        subject.value = 3
        #expect(subject.value == 3)
        subject.send(completion: .finished)

        _ = try await task.value

        #expect(await test.values == [1, 2, 3])
    }

    @Test func currentValueSubjectCanSendValues_ToMultipleConsumers_AndFinish() async throws {
        actor Test {
            var values = [Int]()
            func appendValue(_ value: Int) {
                values.append(value)
            }
        }
        let test = Test()
        let test2 = Test()
        let subject = CurrentValueSubject<Int>(1)

        let taskStartedSubject = SingleValueSubject<Void>()
        let task = Task {
            for try await value in subject.handleEvents(receiveMakeIterator: {
                try? taskStartedSubject.send()
            }) {
                await test.appendValue(value)
            }
        }

        let task2StartedSubject = SingleValueSubject<Void>()
        let task2 = Task {
            for try await value in subject.handleEvents(receiveMakeIterator: {
                try? task2StartedSubject.send()
            }) {
                await test2.appendValue(value)
            }
        }

        try await taskStartedSubject.execute()
        try await task2StartedSubject.execute()

        #expect(await test.values.count < 2)
        #expect(await test2.values.count < 2)

        subject.send(2)
        subject.send(3)
        subject.send(completion: .finished)

        _ = try await task.value
        _ = try await task2.value

        #expect(await test.values == [1, 2, 3])
        #expect(await test2.values == [1, 2, 3])
    }

    @Test func currentValueSubjectStopsSendingValuesUponFinish() async throws {
        actor Test {
            var values = [Int]()
            func appendValue(_ value: Int) {
                values.append(value)
            }
        }
        let test = Test()
        let subject = CurrentValueSubject<Int>(1)
        let taskStartedSubject = SingleValueSubject<Void>()

        let task = Task {
            for try await value in subject.handleEvents(receiveMakeIterator: {
                try? taskStartedSubject.send()
            }) {
                await test.appendValue(value)
            }
        }

        try await taskStartedSubject.execute()

        #expect(await test.values.count < 2)

        subject.send(2)
        subject.send(3)
        subject.send(completion: .finished)

        _ = try await task.value

        let task2StartedSubject = SingleValueSubject<Void>()
        let task2 = Task {
            for try await value in subject.handleEvents(receiveMakeIterator: {
                try? task2StartedSubject.send()
            }) {
                await test.appendValue(value)
            }
        }

        try await task2StartedSubject.execute()

        subject.send(4)

        _ = try await task2.value

        let values = await test.values
        print(values)
        #expect(await test.values == [1, 2, 3])
    }

    @Test func currentValueSubjectCanCompleteWithError() async throws {
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
        let subject = CurrentValueSubject<Int>(1)
        let taskStartedSubject = SingleValueSubject<Void>()

        let task = Task {
            for try await value in subject {
                try? taskStartedSubject.send()
                await test.appendValue(value)
            }
        }

        #expect(await test.values.count < 2)

        try await taskStartedSubject.execute()
        subject.send(completion: .failure(Err.e1))
        subject.send(3)
        subject.send(completion: .finished)

        let task1Result = await task.result
        try #require(throws: Err.e1, performing: { try task1Result.get() })

        let task2StartedSubject = SingleValueSubject<Void>()
        let task2 = Task {
            for try await value in subject.handleEvents(receiveMakeIterator: {
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

    @Test func currentValueSubjectCanSendVoidValues() async throws {
        actor Test {
            var count = 0
            func appendValue() {
                count += 1
            }
        }
        let test = Test()
        let subject = CurrentValueSubject<Void>()
        let taskStartedSubject = SingleValueSubject<Void>()

        let task = Task {
            for try await _ in subject.handleEvents(receiveMakeIterator: {
                try? taskStartedSubject.send()
            }) {
                await test.appendValue()
            }
        }

        try await taskStartedSubject.execute()

        #expect(await test.count < 2)

        subject.send()
        subject.send()
        subject.send(completion: .finished)

        _ = try await task.value

        let task2StartedSubject = SingleValueSubject<Void>()
        let task2 = Task {
            for try await _ in subject.handleEvents(receiveMakeIterator: {
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

    @Test func currentValueSubjectDoesNotReplayValuesSentBeforeSubscribing() async throws {
        let subject = CurrentValueSubject(0)
        subject.send(1)
        subject.send(2)
        subject.send(3)

        let taskStartedSubject = SingleValueSubject<Void>()
        let task = Task {
            var received = [Int]()
            for try await value in subject.handleEvents(receiveMakeIterator: {
                try? taskStartedSubject.send()
            }).prefix(3) {
                received.append(value)
            }
            return received
        }

        try await taskStartedSubject.execute()
        subject.send(4)
        subject.send(5)

        #expect(try await task.value == [3, 4, 5])
    }

    @Test func currentValueSubjectLateSubscriberStartsAtCurrentValue() async throws {
        let subject = CurrentValueSubject(1)

        let firstStarted = SingleValueSubject<Void>()
        let first = Task {
            var received = [Int]()
            for try await value in subject.handleEvents(receiveMakeIterator: {
                try? firstStarted.send()
            }) {
                received.append(value)
            }
            return received
        }
        try await firstStarted.execute()
        subject.send(2)
        subject.send(3)

        let secondStarted = SingleValueSubject<Void>()
        let second = Task {
            var received = [Int]()
            for try await value in subject.handleEvents(receiveMakeIterator: {
                try? secondStarted.send()
            }) {
                received.append(value)
            }
            return received
        }
        try await secondStarted.execute()
        subject.send(4)
        subject.send(completion: .finished)

        #expect(try await first.value == [1, 2, 3, 4])
        #expect(try await second.value == [3, 4])
    }

    @Test func currentValueSubjectSupportsNilCurrentValue() async throws {
        let subject = CurrentValueSubject<Int?>(nil)
        #expect(subject.value == nil)

        let taskStartedSubject = SingleValueSubject<Void>()
        let task = Task {
            var received = [Int?]()
            for try await value in subject.handleEvents(receiveMakeIterator: {
                try? taskStartedSubject.send()
            }) {
                received.append(value)
            }
            return received
        }

        try await taskStartedSubject.execute()
        subject.send(1)
        subject.send(nil)
        subject.send(completion: .finished)

        #expect(try await task.value == [nil, 1, nil])
        #expect(subject.value == nil)
    }

    @Test func currentValueSubjectValueCanChangeAfterCompletionWithoutEmitting() async throws {
        let subject = CurrentValueSubject(1)
        subject.send(completion: .finished)

        subject.send(2)  // Ignored once finished.
        #expect(subject.value == 1)

        subject.value = 3  // Assigning `value` still updates it, as before.
        #expect(subject.value == 3)

        var received = [Int]()
        for try await value in subject { received.append(value) }
        #expect(received.isEmpty)
    }
}
