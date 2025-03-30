////
////  ReplaceNilTests.swift
////
////
////  Created by Tyler Thompson on 10/27/23.
////
//
//import Afluent
//import Foundation
//import Testing
//
//struct ReplaceNilTests {
//    @Test func replaceNilTransformsValue() async throws {
//        let val = try await DeferredTask { nil as Int? }
//            .replaceNil(with: 0)
//            .execute()
//
//        #expect(val == 0)
//    }
//
//    @Test func replaceNilDoesNotTransformValue_IfValueExists() async throws {
//        let val = try await DeferredTask { 1 as Int? }
//            .replaceNil(with: 0)
//            .execute()
//
//        #expect(val == 1)
//    }
//}
