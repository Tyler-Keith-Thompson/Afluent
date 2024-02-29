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
            }.groupBy { element in
                return element.uppercased()
            }
            
            let task = Task {
                var elements = [String]()
                for try await element in stream {
                    elements.append(element)
                }
                XCTAssert(elements.isEmpty)
            }
            
            _ = await task.result
        }
    }
}
