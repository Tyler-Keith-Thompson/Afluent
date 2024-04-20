//
//  EraseToAnyAsynchronousUnitOfWorkTests.swift
//
//
//  Created by Tyler Thompson on 10/30/23.
//

import Afluent
import Foundation
import Testing

struct EraseToAnyAsynchronousUnitOfWorkTests {
    @Test func erasureOfUnitOfWork() async throws {
        let val = try await DeferredTask { true }
            .flatMap { branch -> AnyAsynchronousUnitOfWork<Int> in
                if branch {
                    return DeferredTask { 1 }.eraseToAnyUnitOfWork()
                } else {
                    return DeferredTask { 0 }.eraseToAnyUnitOfWork()
                }
            }.execute()

        #expect(val == 1)
    }

    @Test func erasureOfUnitOfWork_OtherBranch() async throws {
        let val = try await DeferredTask { false }
            .flatMap { branch -> AnyAsynchronousUnitOfWork<Int> in
                if branch {
                    return DeferredTask { 1 }.eraseToAnyUnitOfWork()
                } else {
                    return DeferredTask { 0 }.eraseToAnyUnitOfWork()
                }
            }.execute()

        #expect(val == 0)
    }
}
