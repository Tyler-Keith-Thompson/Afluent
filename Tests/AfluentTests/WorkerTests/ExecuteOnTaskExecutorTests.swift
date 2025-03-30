////
////  ExecuteOnTaskExecutorTests.swift
////  Afluent
////
////  Created by Annalise Mariottini on 10/10/24.
////
//
//import Afluent
//import Foundation
//import Testing
//
//#if swift(>=6)
//    struct ExecuteOnTaskExecutorTests {
//        @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
//        @Test func executesOnExpectedExecutor() async throws {
//            try await DeferredTask {}
//                .handleEvents(receiveOutput: { _ in
//                    dispatchPrecondition(condition: .onQueue(.main))
//                })
//                .execute(executorPreference: .mainQueue)
//
//            try await DeferredTask {}
//                .handleEvents(receiveOutput: { _ in
//                    dispatchPrecondition(condition: .onQueue(.global(qos: .background)))
//                })
//                .execute(executorPreference: .globalQueue(qos: .background))
//
//            let queue = DispatchQueue(label: "\(String(describing: Self.self))\(UUID().uuidString)")
//            try await DeferredTask {}
//                .handleEvents(receiveOutput: { _ in
//                    dispatchPrecondition(condition: .onQueue(queue))
//                })
//                .execute(executorPreference: .queue(queue))
//        }
//
//        @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
//        @Test func runsOnExpectedExecutor() async throws {
//            let completed1 = SingleValueSubject<Void>()
//            let completed2 = SingleValueSubject<Void>()
//            let completed3 = SingleValueSubject<Void>()
//
//            DeferredTask {}
//                .handleEvents(receiveOutput: { _ in
//                    dispatchPrecondition(condition: .onQueue(.main))
//                    try completed1.send()
//                })
//                .run(executorPreference: .mainQueue)
//
//            DeferredTask {}
//                .handleEvents(receiveOutput: { _ in
//                    dispatchPrecondition(condition: .onQueue(.global(qos: .background)))
//                    try completed2.send()
//                })
//                .run(executorPreference: .globalQueue(qos: .background))
//
//            let queue = DispatchQueue(label: "\(String(describing: Self.self))\(UUID().uuidString)")
//            DeferredTask {}
//                .handleEvents(receiveOutput: { _ in
//                    dispatchPrecondition(condition: .onQueue(queue))
//                    try completed3.send()
//                })
//                .run(executorPreference: .queue(queue))
//
//            try await completed1.execute()
//            try await completed2.execute()
//            try await completed3.execute()
//        }
//
//        @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
//        @Test func subscribesOnExpectedExecutor() async throws {
//            let completed1 = SingleValueSubject<Void>()
//            let completed2 = SingleValueSubject<Void>()
//            let completed3 = SingleValueSubject<Void>()
//
//            let sub1 = DeferredTask {}
//                .handleEvents(receiveOutput: { _ in
//                    dispatchPrecondition(condition: .onQueue(.main))
//                    try completed1.send()
//                })
//                .subscribe(executorPreference: .mainQueue)
//
//            let sub2 = DeferredTask {}
//                .handleEvents(receiveOutput: { _ in
//                    dispatchPrecondition(condition: .onQueue(.global(qos: .background)))
//                    try completed2.send()
//                })
//                .subscribe(executorPreference: .globalQueue(qos: .background))
//
//            let queue = DispatchQueue(label: "\(String(describing: Self.self))\(UUID().uuidString)")
//            let sub3 = DeferredTask {}
//                .handleEvents(receiveOutput: { _ in
//                    dispatchPrecondition(condition: .onQueue(queue))
//                    try completed3.send()
//                })
//                .subscribe(executorPreference: .queue(queue))
//
//            noop(sub1)
//            noop(sub2)
//            noop(sub3)
//
//            try await completed1.execute()
//            try await completed2.execute()
//            try await completed3.execute()
//        }
//
//        private func noop(_ any: Any) {}
//    }
//#endif
