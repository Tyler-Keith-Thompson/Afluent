////
////  CollectSequenceTests.swift
////
////
////  Created by Tyler Thompson on 12/23/23.
////
//
//import Afluent
//import Foundation
//import Testing
//
//struct CollectSequenceTests {
//    @Test func testCollectWithEmptySequence() async throws {
//        let emptySequence = [Int]().async
//        let collected = try await emptySequence.collect().first()
//        try #expect(
//            #require(collected).isEmpty,
//            "Collect should return an empty array for an empty sequence")
//    }
//
//    @Test func testCollectWithNonEmptySequence() async throws {
//        let numbers = [1, 2, 3].async
//        let collected = try await numbers.collect().first()
//        #expect(collected == [1, 2, 3], "Collect should return all elements in the sequence")
//    }
//
//    @Test func testCollectWithSequenceContainingSingleElement() async throws {
//        let singleElementSequence = [42].async
//        let collected = try await singleElementSequence.collect().first()
//        #expect(collected == [42], "Collect should return an array with the single element")
//    }
//
//    @Test func testCollectWithSequenceFinishes() async throws {
//        let singleElementSequence = [42].async
//        let collected = try await singleElementSequence.collect().dropFirst().first()
//        #expect(collected == nil)
//    }
//
//    @Test func testCollectWithSequenceThrowingError() async throws {
//        let errorSequence = AsyncThrowingStream<Int, Error> { continuation in
//            continuation.finish(throwing: GeneralError.e1)
//        }
//        await #expect(throws: GeneralError.e1, performing: {
//            _ = try await errorSequence.collect().first()
//        })
//    }
//}
