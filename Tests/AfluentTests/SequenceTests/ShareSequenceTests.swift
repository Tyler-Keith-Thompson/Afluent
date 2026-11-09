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

import Afluent
import AfluentTesting
import Foundation
import Testing

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
        #expect(
            base.events == [ReportingAsyncSequence<Int>.Event.makeAsyncIterator] + expectedNexts + [
                ReportingAsyncSequence<Int>.Event.next
            ])
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

    @Test func AThrowingBaseSequence_BroadcastingToTwoTasks_TheyReceiveTheBaseElementsAndFailure()
        async
    {
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
                while await iterator.next() != nil {}
                let pastEnd = await iterator.next()

                // Then
                #expect(pastEnd == nil)
            }
            group.addTask {
                var iterator = broadcasted.makeAsyncIterator()
                while await iterator.next() != nil {}
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

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test func iteratorCreatedAfterUpstreamFinished_finishesImmediately() async throws {
        let shared = [1, 2, 3].async.broadcast()

        var first = shared.makeAsyncIterator()
        var received = [Int]()
        while let value = await first.next() { received.append(value) }
        #expect(received == [1, 2, 3])

        // The upstream has finished; a new iterator must finish rather than wait forever.
        let late = Task {
            var iterator = shared.makeAsyncIterator()
            return await iterator.next()
        }
        let lateFinished = ManagedFlag()
        Task {
            _ = await late.value
            lateFinished.set()
        }
        try? await wait(until: lateFinished.isSet, timeout: .seconds(2))
        let finishedInTime = lateFinished.isSet
        // Unblocks the iterator if it is stuck, so a regression fails instead of hanging.
        late.cancel()
        #expect(finishedInTime, "An iterator created after the upstream finished never finished")
        #expect(await late.value == nil)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @Test func iteratorCreatedAfterUpstreamFailed_throwsTheFailure() async throws {
        let shared = AsyncThrowingStream<Int, any Error> { continuation in
            continuation.yield(1)
            continuation.finish(throwing: Failure())
        }.broadcast()

        var first = shared.makeAsyncIterator()
        #expect(try await first.next() == 1)
        await #expect(throws: Failure.self) { _ = try await first.next() }

        let late = Task {
            var iterator = shared.makeAsyncIterator()
            return try await iterator.next()
        }
        let lateFinished = ManagedFlag()
        Task {
            _ = await late.result
            lateFinished.set()
        }
        try? await wait(until: lateFinished.isSet, timeout: .seconds(2))
        let finishedInTime = lateFinished.isSet
        late.cancel()
        #expect(finishedInTime, "An iterator created after the upstream failed never finished")
        await #expect(throws: Failure.self) { _ = try await late.value }
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(
        "One consumer of a shared subject cancelling leaves the other consumer receiving values",
        .timeLimit(.minutes(1)))
    func cancellingOneConsumerLeavesTheOtherReceiving() async throws {
        let subject = PassthroughSubject<Int>()
        let (baseSubscribed, baseSubscribedContinuation) = AsyncStream<Void>.makeStream()
        let (consumersSubscribed, consumersSubscribedContinuation) = AsyncStream<Void>.makeStream()
        let shared = subject
            .handleEvents(receiveMakeIterator: { baseSubscribedContinuation.yield() })
            .share()

        let cancelled = Task {
            for try await _ in shared.handleEvents(receiveMakeIterator: {
                consumersSubscribedContinuation.yield()
            }) {}
        }
        let receiving = Task {
            var received = [Int]()
            for try await value in shared.handleEvents(receiveMakeIterator: {
                consumersSubscribedContinuation.yield()
            }) {
                received.append(value)
            }
            return received
        }
        var subscribed = 0
        for await _ in consumersSubscribed {
            subscribed += 1
            if subscribed == 2 { break }
        }
        for await _ in baseSubscribed { break }

        cancelled.cancel()
        _ = await cancelled.result
        subject.send(1)
        subject.send(completion: .finished)

        let received = try await receiving.value
        #expect(received == [1])
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(
        "Cancelling the last consumer of a shared sequence cancels the upstream iteration",
        .timeLimit(.minutes(1)))
    func cancellingTheLastConsumerCancelsTheUpstream() async throws {
        let (started, startedContinuation) = AsyncStream<Void>.makeStream()
        let (upstreamCancelled, upstreamCancelledContinuation) = AsyncStream<Void>.makeStream()
        let (pending, keepOpen) = AsyncStream<Int>.makeStream()
        keepOpen.onTermination = { termination in
            if case .cancelled = termination { upstreamCancelledContinuation.yield() }
        }
        let upstream = pending.handleEvents(receiveMakeIterator: { startedContinuation.yield() })

        // Only the consumer's iterator holds the shared iteration, so cancelling it is the last cancel.
        let consumer = Task {
            for try await _ in upstream.share() {}
        }
        for await _ in started { break }

        consumer.cancel()
        _ = await consumer.result

        var cancelled = false
        for await _ in upstreamCancelled {
            cancelled = true
            break
        }
        keepOpen.finish()
        #expect(cancelled)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test(
        "A consumer already cancelled when it asks a shared sequence for an element finishes",
        .timeLimit(.minutes(1)))
    func consumerCancelledBeforeAskingFinishes() async throws {
        let (pending, keepOpen) = AsyncStream<Int>.makeStream()
        let shared = pending.share()

        let consumer = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            var received = [Int]()
            for try await value in shared {
                received.append(value)
            }
            return received
        }

        let received = try await consumer.value
        keepOpen.finish()
        #expect(received.isEmpty)
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

final class ReportingAsyncSequence<Element: Sendable>: AsyncSequence, AsyncIteratorProtocol,
    @unchecked Sendable
{
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

struct Failure: Error, Equatable {}

func throwOn<T: Equatable>(_ toThrowOn: T, _ value: T) throws -> T {
    if value == toThrowOn {
        throw Failure()
    }
    return value
}

extension RangeReplaceableCollection {
    fileprivate init<Source: AsyncSequence>(_ source: Source) async rethrows
    where Source.Element == Element {
        self.init()
        for try await item in source {
            append(item)
        }
    }
}

private final class ManagedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var _isSet = false
    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isSet
    }
    func set() {
        lock.lock()
        defer { lock.unlock() }
        _isSet = true
    }
}
