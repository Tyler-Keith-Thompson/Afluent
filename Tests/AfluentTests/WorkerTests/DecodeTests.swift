//
//  DecodeTests.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Afluent
import Foundation
import Testing

struct DecodeTests {
    @Test func decodingSuccess() async throws {
        struct MyType: Codable {
            let val: String
        }

        let random = UUID().uuidString
        let res = try await DeferredTask {
            try JSONEncoder().encode(MyType(val: random))
        }
        .decode(type: MyType.self, decoder: JSONDecoder())
        .execute()

        #expect(res.val == random)
    }
}
