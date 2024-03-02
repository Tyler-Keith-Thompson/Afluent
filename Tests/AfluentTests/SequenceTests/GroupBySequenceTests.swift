//
//  GroupBySequenceTests.swift
//
//
//  Created by Trip Phillips on 2/29/24.
//

import Foundation
import XCTest
import Afluent
import Clocks
import ConcurrencyExtras

final class GroupBySequenceTests: XCTestCase {
    func testGroupByWithEmptySequenceReturnsEmpty() async throws {
        await withMainSerialExecutor {
            let stream = AsyncStream<String> { continuation in
                continuation.finish()
            }
                .groupBy { element in
                    return element.uppercased()
                }
                .map {
                    $0.key
                }
                .collect()
            
            let task = Task {
                let keys = try await stream.first()
                XCTAssert(keys?.isEmpty ?? true)
            }
            
            _ = await task.result
        }
    }
}
