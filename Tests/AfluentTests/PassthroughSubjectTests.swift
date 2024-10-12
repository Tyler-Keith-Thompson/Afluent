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
        
        let task = Task {
            for try await value in subject {
                await test.appendValue(value)
            }
        }
        
        #expect(await test.values.isEmpty)
        
        subject.send(1)
        subject.send(2)
        subject.send(3)
        subject.send(completion: .finished)
        
        _ = try await task.value
        
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
        
        let task = Task {
            for try await value in subject {
                await test.appendValue(value)
            }
        }
        
        let task2 = Task {
            for try await value in subject {
                await test2.appendValue(value)
            }
        }
        
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
        print(v)
        print(v2)
        #expect(await test.values == [1, 2, 3])
        #expect(await test2.values == [1, 2, 3])
    }
    
//    @Test func passthroughSubjectStopsSendingValuesUponFinish() async throws {
//        actor Test {
//            var values = [Int]()
//            func appendValue(_ value: Int) {
//                values.append(value)
//            }
//        }
//        let test = Test()
//        let subject = PassthroughSubject<Int>()
//        
//        let task = Task {
//            for try await value in subject {
//                await test.appendValue(value)
//            }
//        }
//        
//        #expect(await test.values.isEmpty)
//        
//        subject.send(1)
//        subject.send(2)
//        subject.send(3)
//        subject.send(completion: .finished)
//        
//        _ = try await task.value
//        
//        let task2 = Task {
//            for try await value in subject {
//                await test.appendValue(value)
//            }
//        }
//        
//        subject.send(4)
//        
//        _ = try await task2.value
//
//        #expect(await test.values == [1, 2, 3])
//    }
}
