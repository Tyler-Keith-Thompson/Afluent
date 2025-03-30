////
////  ToStreamTests.swift
////
////
////  Created by Tyler Thompson on 11/23/23.
////
//
//import Afluent
//import Atomics
//import Foundation
//import Testing
//
//struct ToStreamTests {
//    @Test func convertingUnitOfWorkToAsyncSequence() async throws {
//        let counter = ManagedAtomic(0)
//
//        for try await val in DeferredTask(operation: { 1 }).toAsyncSequence() {
//            counter.wrappingIncrement(ordering: .relaxed)
//            #expect(val == 1)
//        }
//
//        #expect(counter.load(ordering: .relaxed) == 1)
//    }
//}
