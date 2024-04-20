//
//  DiscardOutputTests.swift
//
//
//  Created by Tyler Thompson on 10/28/23.
//

import Afluent
import Foundation
import Testing

struct DiscardOutputTests {
    @Test func discardingOutputChangesToVoid() async throws {
        try await DeferredTask {
            1
        }
        .discardOutput()
        .map { #expect(Bool(true)) }
        .execute()
    }
}
