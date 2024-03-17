//
//  FlatMapSequenceTests.swift
//
//
//  Created by Tyler Thompson on 3/17/24.
//

import Foundation
import XCTest

final class FlatMapSequenceTests: XCTestCase {
    func testFlatMapUnlimitedSequence() async throws {
        struct Seq<Element>: AsyncSequence {
            let val: Element

            struct Iterator: AsyncIteratorProtocol {
                let val: Element
                var sent = false
                mutating func next() async throws -> Element? {
                    if !sent {
                        defer { sent.toggle() }
                        return val
                    } else {
                        return nil
                    }
                }
            }

            func makeAsyncIterator() -> Iterator {
                Iterator(val: val)
            }
        }

        struct SeqOfSeq<Element: AsyncSequence>: AsyncSequence {
            let val1: Element
            let val2: Element

            struct Iterator: AsyncIteratorProtocol {
                let val1: Element
                let val2: Element
                var sent1 = false
                var sent2 = false
                mutating func next() async throws -> Element? {
                    if !sent1 {
                        defer { sent1.toggle() }
                        return val1
                    } else if !sent2 {
                        defer { sent2.toggle() }
                        return val2
                    } else {
                        return nil
                    }
                }
            }

            func makeAsyncIterator() -> Iterator {
                Iterator(val1: val1, val2: val2)
            }
        }

        let seq1 = Seq(val: 1)
        let seq2 = Seq(val: 2)

        let results = try await SeqOfSeq(val1: seq1, val2: seq2)
            .flatMap { $0 }
            .collect()
            .first()

        XCTAssertEqual(try Set(XCTUnwrap(results)), [1, 2])
    }
}
