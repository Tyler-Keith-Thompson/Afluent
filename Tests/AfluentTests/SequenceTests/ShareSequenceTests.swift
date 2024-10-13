//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Async Algorithms open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

//
//  ShareSequenceTests.swift
//  Afluent
//
//  Modified by Tyler Thompson on 9/29/24.
//

import Testing

@_spi(Experimental) import Afluent

@Suite struct ShareSequenceTests {
    @Test func BasicBroadcasting() async {
        let base = [1, 2, 3, 4].async
        let a = base.broadcast()
        let b = a
        let results = await withTaskGroup(of: [Int].self) { group in
            group.addTask {
                await Array(a)
            }
            group.addTask {
                await Array(b)
            }
            return await Array(group)
        }
        #expect(results[0] == results[1])
    }
    
    @Test func BasicBroadcastingFromChannel() async {
        let (base, continuation) = AsyncStream<Int>.makeStream()
        let a = base.broadcast()
        let b = a
        let results = await withTaskGroup(of: [Int].self) { group in
            group.addTask {
                var sent = [Int]()
                for i in 0..<10 {
                    sent.append(i)
                    continuation.yield(i)
                }
                continuation.finish()
                return sent
            }
            group.addTask {
                await Array(a)
            }
            group.addTask {
                await Array(b)
            }
            return await Array(group)
        }
        #expect(results[0] == results[1])
    }
    
    @Test func ABaseSequence_BroadcastingToTwoTasks_TheBaseSequenceIsIteratedOnce() async {
        // Given
        let elements = (0..<10).map { $0 }
        let base = ReportingAsyncSequence(elements)
        
        let expectedNexts = elements.map { _ in ReportingAsyncSequence<Int>.Event.next }
        
        // When
        let broadcasted = base.broadcast()
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for await _ in broadcasted {}
            }
            group.addTask {
                for await _ in broadcasted {}
            }
            await group.waitForAll()
        }
        
        // Then
        #expect(base.events == [ReportingAsyncSequence<Int>.Event.makeAsyncIterator] + expectedNexts + [ReportingAsyncSequence<Int>.Event.next])
    }
    
    @Test func ABaseSequence_BroadcastingToTwoTasks_TheyReceiveTheBaseElements() async {
        // Given
        let base = (0..<10).map { $0 }
        let expected = (0...4).map { $0 }
        
        // When
        let broadcasted = base.async.map { try throwOn(5, $0) }.broadcast()
        let results = await withTaskGroup(of: [Int].self) { group in
            group.addTask {
                var received = [Int]()
                do {
                    for try await element in broadcasted {
                        received.append(element)
                    }
                    Issue.record("The broadcast should fail before finish")
                } catch {
                    #expect(error is Failure)
                }
                
                return received
            }
            group.addTask {
                var received = [Int]()
                do {
                    for try await element in broadcasted {
                        received.append(element)
                    }
                    Issue.record("The broadcast should fail before finish")
                } catch {
                    #expect(error is Failure)
                }
                
                return received
            }
            
            return await Array(group)
        }
        
        // Then
        #expect(results[0] == expected)
        #expect(results[0] == results[1])
    }
    
    @Test func AThrowingBaseSequence_BroadcastingToTwoTasks_TheyReceiveTheBaseElementsAndFailure() async {
        // Given
        let base = (0..<10).map { $0 }
        
        // When
        let broadcasted = base.async.broadcast()
        let results = await withTaskGroup(of: [Int].self) { group in
            group.addTask {
                await Array(broadcasted)
            }
            group.addTask {
                await Array(broadcasted)
            }
            return await Array(group)
        }
        
        // Then
        #expect(results[0] == base)
        #expect(results[0] == results[1])
    }
    
    @Test func ABaseSequence_BroadcastingToTwoTasks_TheyReceiveFinishAndPastEndIsNil() async {
        // Given
        let base = (0..<10).map { $0 }
        
        // When
        let broadcasted = base.async.broadcast()
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                var iterator = broadcasted.makeAsyncIterator()
                while let _ = await iterator.next() {}
                let pastEnd = await iterator.next()
                
                // Then
                #expect(pastEnd == nil)
            }
            group.addTask {
                var iterator = broadcasted.makeAsyncIterator()
                while let _ = await iterator.next() {}
                let pastEnd = await iterator.next()
                
                // Then
                #expect(pastEnd == nil)
            }
            
            await group.waitForAll()
        }
    }
    
    @Test func ABaseSequence_BroadcastingToTwoTasks_TheBufferIsUsed() async {
        let task1IsIsFinished = SingleValueSubject<Void>()
        
        // Given
        let base = (0..<10).map { $0 }
        
        // When
        let broadcasted = base.async.broadcast()
        let results = await withTaskGroup(of: [Int].self) { group in
            group.addTask {
                let result = await Array(broadcasted)
                try? task1IsIsFinished.send()
                return result
            }
            group.addTask {
                var result = [Int]()
                var iterator = broadcasted.makeAsyncIterator()
                let firstElement = await iterator.next()
                result.append(firstElement!)
                try? await task1IsIsFinished.execute()
                
                while let element = await iterator.next() {
                    result.append(element)
                }
                
                return result
            }
            return await Array(group)
        }
        
        // Then
        #expect(results[0] == base)
        #expect(results[0] == results[1])
    }
    
    @Test func AChannel_BroadcastingToTwoTasks_TheyReceivedTheChannelElements() async {
        // Given
        let elements = (0..<10).map { $0 }
        let (base, continuation) = AsyncStream<Int>.makeStream()
        
        // When
        let broadcasted = base.broadcast()
        let results = await withTaskGroup(of: [Int].self) { group in
            group.addTask {
                var sent = [Int]()
                for element in elements {
                    sent.append(element)
                    continuation.yield(element)
                }
                continuation.finish()
                return sent
            }
            group.addTask {
                await Array(broadcasted)
            }
            group.addTask {
                await Array(broadcasted)
            }
            return await Array(group)
        }
        
        // Then
        #expect(results[0] == elements)
        #expect(results[0] == results[1])
    }
}

final class ReportingSequence<Element>: Sequence, IteratorProtocol {
    enum Event: Equatable, CustomStringConvertible {
        case next
        case makeIterator
        
        var description: String {
            switch self {
            case .next: return "next()"
            case .makeIterator: return "makeIterator()"
            }
        }
    }
    
    var events = [Event]()
    var elements: [Element]
    
    init(_ elements: [Element]) {
        self.elements = elements
    }
    
    func next() -> Element? {
        events.append(.next)
        guard elements.count > 0 else {
            return nil
        }
        return elements.removeFirst()
    }
    
    func makeIterator() -> ReportingSequence {
        events.append(.makeIterator)
        return self
    }
}

final class ReportingAsyncSequence<Element: Sendable>: AsyncSequence, AsyncIteratorProtocol, @unchecked Sendable {
    enum Event: Equatable, CustomStringConvertible {
        case next
        case makeAsyncIterator
        
        var description: String {
            switch self {
            case .next: return "next()"
            case .makeAsyncIterator: return "makeAsyncIterator()"
            }
        }
    }
    
    var events = [Event]()
    var elements: [Element]
    
    init(_ elements: [Element]) {
        self.elements = elements
    }
    
    func next() async -> Element? {
        events.append(.next)
        guard elements.count > 0 else {
            return nil
        }
        return elements.removeFirst()
    }
    
    func makeAsyncIterator() -> ReportingAsyncSequence {
        events.append(.makeAsyncIterator)
        return self
    }
}

struct Failure: Error, Equatable { }

func throwOn<T: Equatable>(_ toThrowOn: T, _ value: T) throws -> T {
    if value == toThrowOn {
        throw Failure()
    }
    return value
}

extension Array where Element: Sendable {
    fileprivate var async: AsyncStream<Element> {
        AsyncStream<Element> {
            for item in self {
                $0.yield(item)
            }
            $0.finish()
        }
    }
}

fileprivate extension RangeReplaceableCollection {
    init<Source: AsyncSequence>(_ source: Source) async rethrows where Source.Element == Element {
        self.init()
        for try await item in source {
            append(item)
        }
    }
}
