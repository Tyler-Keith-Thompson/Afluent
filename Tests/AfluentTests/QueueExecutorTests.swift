//
//  QueueExecutorTasks.swift
//
//
//  Created by Annalise Mariottini on 10/10/24.
//

@testable import Afluent
import Foundation
import Testing

#if swift(>=6)
struct QueueExecutorTests {
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    @Test func runsOnExpectedQueue() async throws {
        await Task.detached(executorPreference: .mainQueue) {
            dispatchPrecondition(condition: .onQueue(.main))
        }.value

        await Task.detached(executorPreference: .globalQueue(qos: .background)) {
            dispatchPrecondition(condition: .onQueue(.global(qos: .background)))
        }.value

        let queue = DispatchQueue(label: "\(String(describing: Self.self))\(UUID().uuidString)")
        await Task.detached(executorPreference: .queue(queue)) {
            dispatchPrecondition(condition: .onQueue(queue))
        }.value
    }

    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    @Test func hasSharedMainQueueInstance() {
        let executor1 = QueueExecutor.mainQueue
        let executor2 = QueueExecutor.mainQueue
        #expect(executor1 === executor2)
    }

    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    @Test(arguments: [
        DispatchQoS.QoSClass.background, .default, .unspecified, .userInitiated, .userInteractive,
    ]) func hasSharedGlobalQOSInstances(qos: DispatchQoS.QoSClass) {
        let executor1 = QueueExecutor.globalQueue(qos: qos)
        let executor2 = QueueExecutor.globalQueue(qos: qos)
        #expect(executor1 === executor2)
    }

    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    @Test func forwardsTaskLocalsWhenUsed() async throws {
        enum Context {
            @TaskLocal static var value: String?
        }

        let expectedValue = UUID().uuidString

        #expect(Context.value == nil)

        Context.$value.withValue(expectedValue) {
            Task(executorPreference: .mainQueue) {
                dispatchPrecondition(condition: .onQueue(.main))
                #expect(Context.value == expectedValue)
            }
        }

        Context.$value.withValue(expectedValue) {
            Task(executorPreference: .globalQueue(qos: .background)) {
                dispatchPrecondition(condition: .onQueue(.global(qos: .background)))
                #expect(Context.value == expectedValue)
            }
        }

        let queue = DispatchQueue(label: "\(String(describing: Self.self))\(UUID().uuidString)")
        Context.$value.withValue(expectedValue) {
            Task(executorPreference: .queue(queue)) {
                dispatchPrecondition(condition: .onQueue(queue))
                #expect(Context.value == expectedValue)
            }
        }
    }
}

#if os(Linux)
extension DispatchQoS.QoSClass: @unchecked Sendable { }
#endif

#endif
