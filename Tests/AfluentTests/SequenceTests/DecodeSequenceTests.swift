//
//  DecodeSequenceTests.swift
//  
//
//  Created by Tyler Thompson on 12/10/23.
//

import Foundation
import Afluent
import XCTest

final class DecodeSequenceTests: XCTestCase {
    func testDecodingSuccess() async throws {
        struct MyType: Codable {
            let val: String
        }
        
        let random = UUID().uuidString
        let res = try await DeferredTask {
            try JSONEncoder().encode(MyType(val: random))
        }
            .toAsyncSequence()
            .decode(type: MyType.self, decoder: JSONDecoder())
            .first()
        
        XCTAssertEqual(res?.val, random)
    }
}
