//
//  ToStreamTests.swift
//
//
//  Created by Tyler Thompson on 11/23/23.
//

import Foundation
import Afluent
import XCTest

import Atomics

final class ToStreamTests: XCTestCase {
    func testConvertingUnitOfWorkToAsyncSequence() async throws {
        let counter = ManagedAtomic(0)
        
        for try await val in DeferredTask(operation: { 1 }).toAsyncSequence() {
            counter.wrappingIncrement(ordering: .relaxed)
            XCTAssertEqual(val, 1)
        }
        
        XCTAssertEqual(counter.load(ordering: .relaxed), 1)
    }
}
