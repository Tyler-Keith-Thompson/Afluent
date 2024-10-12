//
//  PassthroughSubjectTests.swift
//  Afluent
//
//  Created by Tyler Thompson on 10/12/24.
//

import Testing
@_spi(Experimental) import Afluent

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
            for try await value in subject.handleEvents(receiveMakeIterator: {
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
        
        #expect(await test.values.isEmpty)
        #expect(await test2.values.isEmpty)

        subject.send(1)
        subject.send(2)
        subject.send(3)
        subject.send(completion: .finished)
        
        _ = try await task.value
        _ = try await task2.value

        let v = await test.values
        let v2 = await test2.values

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
            for try await value in subject.handleEvents(receiveMakeIterator: {
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
            for try await value in subject.handleEvents(receiveMakeIterator: {
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

        let task = Task {
            for try await value in subject {
                try? taskStartedSubject.send()
                await test.appendValue(value)
            }
        }
        
        #expect(await test.values.isEmpty)
        
        subject.send(1)
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
            for try await _ in subject.handleEvents(receiveMakeIterator: {
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
}
