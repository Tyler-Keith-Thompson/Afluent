////
////  EncodeSequenceTests.swift
////
////
////  Created by Tyler Thompson on 12/10/23.
////
//
//import Afluent
//import Foundation
//import Testing
//
//struct EncodeSequenceTests {
//    @Test func encodingSuccess() async throws {
//        struct MyType: Codable {
//            let val: String
//        }
//
//        let random = UUID().uuidString
//        let res = try await DeferredTask {
//            MyType(val: random)
//        }
//        .toAsyncSequence()
//        .encode(encoder: JSONEncoder())
//        .first()
//
//        try #expect(JSONDecoder().decode(MyType.self, from: #require(res)).val == random)
//    }
//}
