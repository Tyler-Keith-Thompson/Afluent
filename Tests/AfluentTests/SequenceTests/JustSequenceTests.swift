//
//  JustSequenceTests.swift
//
//
//  Created by Tyler Thompson on 12/24/23.
//

import Afluent
import Foundation
import Testing

struct JustSequenceTests {
    @Test("Just emits its value once, then finishes", .timeLimit(.minutes(1)))
    func justEmitsItsValueOnceThenFinishes() async throws {
        let sut = Just(1)
        let expected = [1]

        var actual = [Int]()
        for try await element in sut { actual.append(element) }

        #expect(actual == expected)
    }
}
