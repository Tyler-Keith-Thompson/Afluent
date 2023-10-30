//
//  EraseToAnyAsynchronousUnitOfWorkTests.swift
//
//
//  Created by Tyler Thompson on 10/30/23.
//

import Foundation
import Afluent
import XCTest

final class EraseToAnyAsynchronousUnitOfWorkTests: XCTestCase {
    func testErasureOfUnitOfWork() async throws {
        let val = try await DeferredTask { true }
            .flatMap { branch -> AnyAsynchronousUnitOfWork<Int> in
                if branch {
                    return DeferredTask { 1 }.eraseToAnyUnitOfWork()
                } else {
                    return DeferredTask { 0 }.eraseToAnyUnitOfWork()
                }
            }.execute()
        
        XCTAssertEqual(val, 1)
    }
    
    func testErasureOfUnitOfWork_OtherBranch() async throws {
        let val = try await DeferredTask { false }
            .flatMap { branch -> AnyAsynchronousUnitOfWork<Int> in
                if branch {
                    return DeferredTask { 1 }.eraseToAnyUnitOfWork()
                } else {
                    return DeferredTask { 0 }.eraseToAnyUnitOfWork()
                }
            }.execute()
        
        XCTAssertEqual(val, 0)
    }
}
