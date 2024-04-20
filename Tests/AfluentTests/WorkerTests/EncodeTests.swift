//
//  EncodeTests.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Afluent
import Foundation
import Testing

struct EncodeTests {
    @Test func encodingSuccess() async throws {
        struct MyType: Codable {
            let val: String
        }

        let random = UUID().uuidString
        let res = try await DeferredTask {
            MyType(val: random)
        }
        .encode(encoder: JSONEncoder())
        .execute()

        try #expect(JSONDecoder().decode(MyType.self, from: res).val == random)
    }
}
