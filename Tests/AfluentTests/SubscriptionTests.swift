////
////  SubscriptionTests.swift
////
////
////  Created by Tyler Thompson on 10/30/23.
////
//
//import Afluent
//import Clocks
//import ConcurrencyExtras
//import Foundation
//import Testing
//
//struct SubscriptionTests {
//    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
//    @Test func deferredTaskCancelledBeforeItEnds() async throws {
//        try await withMainSerialExecutor {
//            actor Test {
//                var started = false
//                var ended = false
//
//                func start() { started = true }
//                func end() { ended = true }
//            }
//            let test = Test()
//            let testStartSubject = SingleValueSubject<Void>()
//            let cancellationSubject = SingleValueSubject<Void>()
//            let sub = SingleValueSubject<Void>()
//
//            var subscription: AnyCancellable?
//            subscription = DeferredTask {
//                await test.start()
//                try testStartSubject.send()
//                try await cancellationSubject.execute()
//            }
//            .handleEvents(receiveCancel: {
//                try sub.send()
//            })
//            .map {
//                await test.end()
//            }.subscribe()
//
//            try await testStartSubject.execute()
//            subscription?.cancel()
//            try cancellationSubject.send()
//
//            try await sub.execute()
//
//            let started = await test.started
//            let ended = await test.ended
//
//            #expect(started)
//            #expect(!ended)
//        }
//    }
//
//    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
//    @Test func deferredTaskCancelledViaDeinitialization() async throws {
//        try await withMainSerialExecutor {
//            actor Test {
//                var started = false
//                var ended = false
//
//                func start() { started = true }
//                func end() { ended = true }
//            }
//            let test = Test()
//            let testStartSubject = SingleValueSubject<Void>()
//            let cancellationSubject = SingleValueSubject<Void>()
//            let sub = SingleValueSubject<Void>()
//
//            var subscription: AnyCancellable?
//            subscription = DeferredTask {
//                await test.start()
//                try testStartSubject.send()
//                try await cancellationSubject.execute()
//            }
//            .handleEvents(receiveCancel: {
//                try? sub.send()
//            })
//            .map {
//                await test.end()
//            }
//            .subscribe()
//
//            noop(subscription)
//
//            try await testStartSubject.execute()
//            subscription = nil
//            try cancellationSubject.send()
//
//            try await sub.execute()
//
//            let started = await test.started
//            let ended = await test.ended
//
//            #expect(started)
//            #expect(!ended)
//        }
//    }
//
//    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
//    @Test func deferredTaskCancelledViaDeinitialization_WhenStoredInSet() async throws {
//        try await withMainSerialExecutor {
//            actor Test {
//                var started = false
//                var ended = false
//
//                func start() { started = true }
//                func end() { ended = true }
//            }
//            let test = Test()
//            let testStartSubject = SingleValueSubject<Void>()
//            let cancellationFinishedSubject = SingleValueSubject<Void>()
//            let sub = SingleValueSubject<Void>()
//            var set = Set<AnyCancellable>()
//
//            DeferredTask {
//                await test.start()
//                try testStartSubject.send()
//                try await cancellationFinishedSubject.execute()
//            }
//            .handleEvents(receiveCancel: {
//                try? sub.send()
//            })
//            .map {
//                await test.end()
//            }
//            .subscribe()
//            .store(in: &set)
//
//            try await testStartSubject.execute()
//            set.removeAll()
//            try cancellationFinishedSubject.send()
//
//            try await sub.execute()
//
//            let started = await test.started
//            let ended = await test.ended
//
//            #expect(started)
//            #expect(!ended)
//        }
//    }
//
//    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
//    @Test func deferredTaskCancelledViaDeinitialization_WhenStoredInCollection() async throws {
//        try await withMainSerialExecutor {
//            actor Test {
//                var started = false
//                var ended = false
//
//                func start() { started = true }
//                func end() { ended = true }
//            }
//            let test = Test()
//            let testStartSubject = SingleValueSubject<Void>()
//            let cancellationFinishedSubject = SingleValueSubject<Void>()
//            let sub = SingleValueSubject<Void>()
//            var collection = [AnyCancellable]()
//
//            DeferredTask {
//                await test.start()
//                try? testStartSubject.send()
//                try await cancellationFinishedSubject.execute()
//            }
//            .handleEvents(receiveCancel: {
//                try? sub.send()
//            })
//            .map {
//                await test.end()
//            }
//            .subscribe()
//            .store(in: &collection)
//
//            try await testStartSubject.execute()
//            collection.removeAll()
//            try cancellationFinishedSubject.send()
//
//            try await sub.execute()
//
//            let started = await test.started
//            let ended = await test.ended
//
//            #expect(started)
//            #expect(!ended)
//        }
//    }
//
//    // MARK: AsyncSequence
//
//    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
//    @Test func asyncSequenceCancelledBeforeItEnds() async throws {
//        try await withMainSerialExecutor {
//            actor Test {
//                var started = false
//                var ended = false
//                var subscription: AnyCancellable?
//
//                func start() { started = true }
//                func end() { ended = true }
//
//                func setSubscription(_ subscription: AnyCancellable?) {
//                    self.subscription = subscription
//                }
//            }
//            let test = Test()
//
//            let sub = SingleValueSubject<Void>()
//            await test.setSubscription(
//                AsyncStream<AnyCancellable?> { continuation in
//                    Task {
//                        await test.start()
//                        continuation.yield(await test.subscription)
//                    }
//                }
//                .map { $0?.cancel() }
//                .handleEvents(receiveCancel: {
//                    try sub.send()
//                })
//                .map {
//                    if !Task.isCancelled {
//                        await test.end()
//                    }
//                }
//                .sink())
//
//            try await sub.execute()
//
//            let started = await test.started
//            let ended = await test.ended
//
//            #expect(started)
//            #expect(!ended)
//        }
//    }
//
//    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
//    @Test func asyncSequenceCancelledViaDeinitialization() async throws {
//        try await withMainSerialExecutor {
//            actor Test {
//                var started = false
//                var ended = false
//
//                func start() { started = true }
//                func end() { ended = true }
//            }
//            let testStartSubject = SingleValueSubject<Void>()
//            let test = Test()
//            let clock = TestClock()
//
//            let sequence = AsyncStream<Void> { continuation in
//                Task {
//                    await test.start()
//                    try testStartSubject.send()
//                    try await clock.sleep(for: .milliseconds(10))
//                    continuation.yield()
//                }
//            }.map {
//                await test.end()
//            }
//
//            var subscription: AnyCancellable? = sequence.sink()
//            noop(subscription)
//
//            try await testStartSubject.execute()
//
//            subscription = nil
//
//            await clock.advance(by: .milliseconds(10))
//
//            let started = await test.started
//            let ended = await test.ended
//
//            #expect(started)
//            #expect(!ended)
//        }
//    }
//
//    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
//    @Test func asyncSequenceCancelledViaDeinitialization_WhenStoredInSet() async throws {
//        try await withMainSerialExecutor {
//            actor Test {
//                var started = false
//                var ended = false
//
//                func start() { started = true }
//                func end() { ended = true }
//            }
//            let test = Test()
//            var set = Set<AnyCancellable>()
//            let clock = TestClock()
//            let sub = SingleValueSubject<Void>()
//
//            let sequence = AsyncStream<Void> { continuation in
//                Task {
//                    try sub.send()
//                    await test.start()
//                    try await clock.sleep(for: .milliseconds(10))
//                    continuation.yield()
//                }
//            }.map {
//                await test.end()
//            }
//
//            sequence.sink()
//                .store(in: &set)
//
//            try await sub.execute()
//
//            set.removeAll()
//
//            await clock.advance(by: .milliseconds(10))
//
//            let started = await test.started
//            let ended = await test.ended
//
//            #expect(started)
//            #expect(!ended)
//        }
//    }
//
//    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
//    @Test func asyncSequenceCancelledViaDeinitialization_WhenStoredInCollection() async throws {
//        try await withMainSerialExecutor {
//            actor Test {
//                var started = false
//                var ended = false
//
//                func start() { started = true }
//                func end() { ended = true }
//            }
//            let test = Test()
//            var collection = [AnyCancellable]()
//            let clock = TestClock()
//            let sub = SingleValueSubject<Void>()
//
//            let sequence = AsyncStream<Void> { continuation in
//                Task {
//                    try sub.send()
//                    await test.start()
//                    try await clock.sleep(for: .milliseconds(10))
//                    continuation.yield()
//                }
//            }.map {
//                await test.end()
//            }
//
//            sequence.sink()
//                .store(in: &collection)
//
//            try await sub.execute()
//
//            collection.removeAll()
//
//            await clock.advance(by: .milliseconds(10))
//
//            let started = await test.started
//            let ended = await test.ended
//
//            #expect(started)
//            #expect(!ended)
//        }
//    }
//
//    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
//    @Test func asyncSequenceReceivesCompletionWhenCancelled() async throws {
//        try await withMainSerialExecutor {
//            actor Test {
//                var started = false
//                var ended = false
//                var output = false
//
//                func start() { started = true }
//                func end() { ended = true }
//                func receivedOutput() { output = true }
//            }
//            let test = Test()
//            let testStartSubject = SingleValueSubject<Void>()
//            let clock = TestClock()
//
//            let sequence = AsyncThrowingStream<Void, Error> { continuation in
//                Task {
//                    await test.start()
//                    try testStartSubject.send()
//                    try await clock.sleep(for: .milliseconds(10))
//                    continuation.yield()
//                }
//            }.map {
//                await test.end()
//            }
//
//            let completedChannel = SingleValueChannel<Void>()
//
//            let subscription = sequence.sink { completion in
//                switch completion {
//                    case .finished: break
//                    case .failure(let error): Issue.record("Unexpected error \(error)")
//                }
//                try? await completedChannel.send()
//            } receiveOutput: {
//                await test.receivedOutput()
//            }
//
//            try await testStartSubject.execute()
//
//            subscription.cancel()
//
//            await clock.advance(by: .milliseconds(10))
//
//            try await completedChannel.execute()
//
//            try await Task.sleep(for: .milliseconds(9))
//
//            let started = await test.started
//            let ended = await test.ended
//            let output = await test.output
//
//            #expect(started)
//            #expect(!ended)
//            #expect(!output)
//        }
//    }
//
//    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
//    @Test func asyncSequenceReceivesCompletionWhenStreamCompletes() async throws {
//        try await withMainSerialExecutor {
//            actor Test {
//                var started = false
//                var ended = false
//                var output = false
//
//                func start() { started = true }
//                func end() { ended = true }
//                func receivedOutput() { output = true }
//            }
//            let test = Test()
//
//            let sequence = AsyncThrowingStream<Void, Error> { continuation in
//                Task {
//                    await test.start()
//                    continuation.finish()
//                }
//            }.map {
//                await test.end()
//            }
//
//            let completedChannel = SingleValueChannel<Void>()
//
//            let subscription = sequence.sink { completion in
//                switch completion {
//                    case .finished: break
//                    case .failure(let error): Issue.record("Unexpected error \(error)")
//                }
//                try? await completedChannel.send()
//            } receiveOutput: {
//                await test.receivedOutput()
//            }
//            noop(subscription)
//
//            try await completedChannel.execute()
//
//            try await Task.sleep(for: .milliseconds(10))
//
//            let started = await test.started
//            let ended = await test.ended
//            let output = await test.output
//
//            #expect(started)
//            #expect(!ended)
//            #expect(!output)
//        }
//    }
//
//    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
//    @Test func asyncSequenceReceivesOutputThenCompletionWhenCancelled() async throws {
//        try await withMainSerialExecutor {
//            actor Test {
//                var started = false
//                var ended = false
//
//                func start() { started = true }
//                func end() { ended = true }
//            }
//            let test = Test()
//
//            let exp = SingleValueSubject<Void>()
//            let sequence = AsyncStream<Void> { continuation in
//                Task {
//                    await test.start()
//                    continuation.yield()
//                }
//            }.map {
//                await test.end()
//                try? exp.send()
//            }
//
//            let completedChannel = SingleValueChannel<Void>()
//            let outputExp = SingleValueSubject<Void>()
//
//            let subscription = sequence.sink { completion in
//                switch completion {
//                    case .finished: break
//                    case .failure(let error): Issue.record("Unexpected error \(error)")
//                }
//                try? await completedChannel.send()
//            } receiveOutput: {
//                try? outputExp.send()
//            }
//
//            try await Task.sleep(for: .milliseconds(2))
//
//            subscription.cancel()
//
//            try await completedChannel.execute()
//
//            try await exp.execute()
//            try await outputExp.execute()
//
//            let started = await test.started
//            let ended = await test.ended
//
//            #expect(started)
//            #expect(ended)
//        }
//    }
//
//    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
//    @Test func asyncSequenceReceivesErrorInCompletion() async throws {
//        try await withMainSerialExecutor {
//            actor Test {
//                var started = false
//                var ended = false
//                var output = false
//
//                func start() { started = true }
//                func end() { ended = true }
//                func receivedOutput() { output = true }
//            }
//            let test = Test()
//
//            enum Err: Error, Equatable { case e1 }
//
//            let sequence = AsyncThrowingStream<Void, Error> { continuation in
//                Task {
//                    await test.start()
//                    continuation.yield(with: .failure(Err.e1))
//                }
//            }.map {
//                await test.end()
//            }
//
//            let completedChannel = SingleValueChannel<Void>()
//
//            let subscription = sequence.sink { completion in
//                switch completion {
//                    case .finished: Issue.record("Unexpected normal finish")
//                    case .failure(let error): #expect(error as? Err == .e1)
//                }
//                try? await completedChannel.send()
//            } receiveOutput: {
//                await test.receivedOutput()
//            }
//
//            try await Task.sleep(for: .milliseconds(2))
//
//            subscription.cancel()
//
//            try await completedChannel.execute()
//
//            try await Task.sleep(for: .milliseconds(9))
//
//            let started = await test.started
//            let ended = await test.ended
//            let output = await test.output
//
//            #expect(started)
//            #expect(!ended)
//            #expect(!output)
//        }
//    }
//}
//
//@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
//extension SubscriptionTests {
//    func noop(_: Any?) {}
//}
