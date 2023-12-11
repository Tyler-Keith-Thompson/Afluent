//
//  EncodeTests.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Afluent
import Foundation
import XCTest

final class EncodeTests: XCTestCase {
    func testEncodingSuccess() async throws {
        struct MyType: Codable {
            let val: String
        }

        let random = UUID().uuidString
        let res = try await DeferredTask {
            MyType(val: random)
        }
        .encode(encoder: JSONEncoder())
        .execute()

        XCTAssertEqual(try JSONDecoder().decode(MyType.self, from: res).val, random)
    }
}
