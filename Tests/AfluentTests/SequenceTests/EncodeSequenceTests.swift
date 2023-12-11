//
//  EncodeSequenceTests.swift
//
//
//  Created by Tyler Thompson on 12/10/23.
//

import Afluent
import Foundation
import XCTest

final class EncodeSequenceTests: XCTestCase {
    func testEncodingSuccess() async throws {
        struct MyType: Codable {
            let val: String
        }

        let random = UUID().uuidString
        let res = try await DeferredTask {
            MyType(val: random)
        }
        .toAsyncSequence()
        .encode(encoder: JSONEncoder())
        .first()

        XCTAssertEqual(try JSONDecoder().decode(MyType.self, from: XCTUnwrap(res)).val, random)
    }
}
