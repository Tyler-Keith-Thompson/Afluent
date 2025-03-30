////
////  MapTests.swift
////
////
////  Created by Tyler Thompson on 10/27/23.
////
//
//import Afluent
//import Foundation
//import Testing
//
//struct MapTests {
//    @Test func mapTransformsValue() async throws {
//        let val = try await DeferredTask { 1 }
//            .map { String(describing: $0) }
//            .execute()
//
//        #expect(val == "1")
//    }
//
//    @Test func mapTransformsWithKeypath() async throws {
//        struct Obj {
//            let val = 0
//            let other = 1
//        }
//
//        let val = try await DeferredTask { Obj() }
//            .map(\.val)
//            .execute()
//
//        #expect(val == 0)
//    }
//
//    @Test func tryMapTransformsValue() async throws {
//        let val = try await DeferredTask { 1 }
//            .tryMap { String(describing: $0) }
//            .execute()
//
//        #expect(val == "1")
//    }
//
//    @Test func tryMapThrowsError() async throws {
//        let val = try await DeferredTask { 1 }
//            .tryMap { _ in throw GeneralError.e1 }
//            .result
//
//        #expect { try val.get() } throws: { error in
//            error as? GeneralError == GeneralError.e1
//        }
//    }
//}
