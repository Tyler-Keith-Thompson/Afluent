////
////  ReplaceErrorSequenceTests.swift
////
////
////  Created by Tyler Thompson on 12/19/23.
////
//
//import Afluent
//import Foundation
//import Testing
//
//struct ReplaceErrorSequenceTests {
//    @Test func replaceErrorTransformsValue() async throws {
//        let val = try await DeferredTask { throw GeneralError.e1 }
//            .toAsyncSequence()
//            .replaceError(with: -1)
//            .first()
//
//        #expect(val == -1)
//    }
//
//    @Test func replaceNilDoesNotTransformValue_IfNoErrorThrown() async throws {
//        let val = try await DeferredTask { 1 }
//            .toAsyncSequence()
//            .replaceError(with: -1)
//            .first()
//
//        #expect(val == 1)
//    }
//}
