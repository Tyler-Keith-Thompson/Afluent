////
////  UnwrapOrThrowTests.swift
////
////
////  Created by Tyler Thompson on 11/2/23.
////
//
//import Afluent
//import Foundation
//import Testing
//
//struct UnwrapOrThrowTests {
//    @Test func unwrapThrowsErrorIfOptionalIsNone() async throws {
//        enum Err: Error {
//            case e1
//        }
//
//        let result = try await DeferredTask {
//            nil as Int?
//        }
//        .unwrap(orThrow: Err.e1)
//        .result
//
//        #expect { try result.get() } throws: { error in
//            error as? Err == .e1
//        }
//    }
//
//    @Test func unwrapThrowsErrorIfOptionalIsSome() async throws {
//        enum Err: Error {
//            case e1
//        }
//
//        let result = try await DeferredTask {
//            1 as Int?
//        }
//        .unwrap(orThrow: Err.e1)
//        .result
//
//        try #expect(result.get() == 1)
//    }
//}
