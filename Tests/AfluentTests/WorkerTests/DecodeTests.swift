//
//  DecodeTests.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Afluent
import Foundation
import XCTest

final class DecodeTests: XCTestCase {
    func testDecodingSuccess() async throws {
        struct MyType: Codable {
            let val: String
        }

        let random = UUID().uuidString
        let res = try await DeferredTask {
            try JSONEncoder().encode(MyType(val: random))
        }
        .decode(type: MyType.self, decoder: JSONDecoder())
        .execute()

        XCTAssertEqual(res.val, random)
    }
}
