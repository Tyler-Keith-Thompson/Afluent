////
////  DecodeSequenceTests.swift
////
////
////  Created by Tyler Thompson on 12/10/23.
////
//
//import Afluent
//import Foundation
//import Testing
//
//struct DecodeSequenceTests {
//    @Test func testDecodingSuccess() async throws {
//        struct MyType: Codable {
//            let val: String
//        }
//
//        let random = UUID().uuidString
//        let res = try await DeferredTask {
//            try JSONEncoder().encode(MyType(val: random))
//        }
//        .toAsyncSequence()
//        .decode(type: MyType.self, decoder: JSONDecoder())
//        .first()
//
//        #expect(res?.val == random)
//    }
//}
