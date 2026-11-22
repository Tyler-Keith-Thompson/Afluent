//
//  BatchSequencePropertyTests.swift
//  Afluent
//

import Afluent
import Foundation
import PropertyBased
import Testing

struct BatchSequencePropertyTests {
    @Test(
        "count(n) emits the elements in order in arrays of n, then the remainder, like chunking by hand",
        .timeLimit(.minutes(1)))
    func countMatchesChunkingByHand() async throws {
        await propertyCheck(
            count: 200, input: Gen.int(in: -1000...1000).array(of: 0...64), Gen.int(in: 1...10)
        ) { elements, count in
            var expected = [[Int]]()
            var index = 0
            while index < elements.count {
                let end = min(index + count, elements.count)
                expected.append(Array(elements[index..<end]))
                index = end
            }

            var actual = [[Int]]()
            for try await batch in elements.async.batch(strategy: .count(count)) {
                actual.append(batch)
            }

            #expect(actual == expected)
        }
    }
}
