//
//  CollectSequenceTests.swift
//
//
//  Created by Tyler Thompson on 12/23/23.
//

import Afluent
import Foundation
import XCTest

final class CollectSequenceTests: XCTestCase {
    func testCollectWithEmptySequence() async throws {
        let emptySequence = [Int]().async
        let collected = try await emptySequence.collect().first()
        XCTAssertTrue(try XCTUnwrap(collected).isEmpty, "Collect should return an empty array for an empty sequence")
    }

    func testCollectWithNonEmptySequence() async throws {
        let numbers = [1, 2, 3].async
        let collected = try await numbers.collect().first()
        XCTAssertEqual(collected, [1, 2, 3], "Collect should return all elements in the sequence")
    }

    func testCollectWithSequenceContainingSingleElement() async throws {
        let singleElementSequence = [42].async
        let collected = try await singleElementSequence.collect().first()
        XCTAssertEqual(collected, [42], "Collect should return an array with the single element")
    }

    func testCollectWithSequenceThrowingError() async throws {
        enum TestError: Error, Equatable {
            case someError
        }

        let errorSequence = AsyncThrowingStream<Int, Error> { continuation in
            continuation.finish(throwing: TestError.someError)
        }
        do {
            _ = try await errorSequence.collect().first()
            XCTFail("Collect should throw the error encountered in the sequence")
        } catch {
            XCTAssertEqual(error as? TestError, .someError, "Collect should throw the correct error")
        }
    }
}

extension Array {
    fileprivate var async: AsyncStream<Element> {
        AsyncStream { continuation in
            for element in self {
                continuation.yield(element)
            }
            continuation.finish()
        }
    }
}
