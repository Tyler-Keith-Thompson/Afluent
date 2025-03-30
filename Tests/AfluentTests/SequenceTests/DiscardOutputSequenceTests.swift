////
////  DiscardOutputSequenceTests.swift
////
////
////  Created by Tyler Thompson on 12/10/23.
////
//
//import Afluent
//import Foundation
//import Testing
//
//struct DiscardOutputSequenceTests {
//    @Test func discardingOutputChangesToVoid() async throws {
//        try await DeferredTask {
//            1
//        }
//        .toAsyncSequence()
//        .discardOutput()
//        .map { #expect(Bool(true)) }
//        .first()
//    }
//}
