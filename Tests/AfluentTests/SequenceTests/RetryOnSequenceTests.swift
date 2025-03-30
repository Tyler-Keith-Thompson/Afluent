////
////  RetryOnSequenceTests.swift
////
////
////  Created by Tyler Thompson on 11/28/23.
////
//
//import Afluent
//import Foundation
//import Testing
//
//struct RetryOnSequenceTests {
//    @Test func taskCanRetryADefinedNumberOfTimes() async throws {
//        enum Err: Error, Equatable {
//            case e1
//        }
//        actor Test {
//            var arr = [String]()
//            func append(_ str: String) {
//                arr.append(str)
//            }
//        }
//
//        let test = Test()
//        let retryCount = UInt.random(in: 2...10)
//
//        let t = Task {
//            try await DeferredTask {
//                await test.append("called")
//            }
//            .toAsyncSequence()
//            .map { _ in throw Err.e1 }
//            .retry(retryCount, on: Err.e1)
//            .first()
//        }
//
//        _ = await t.result
//
//        let copy = await test.arr
//        #expect(UInt(copy.count) == retryCount + 1)
//    }
//
//    @Test func taskCanRetryZero_DoesNothing() async throws {
//        enum Err: Error, Equatable {
//            case e1
//        }
//        actor Test {
//            var arr = [String]()
//            func append(_ str: String) {
//                arr.append(str)
//            }
//        }
//
//        let test = Test()
//
//        let t = Task {
//            try await DeferredTask {
//                await test.append("called")
//            }
//            .toAsyncSequence()
//            .map { _ in throw Err.e1 }
//            .retry(0, on: Err.e1)
//            .first()
//        }
//
//        _ = await t.result
//
//        let copy = await test.arr
//        #expect(UInt(copy.count) == 1)
//    }
//
//    @Test func taskCanRetryDefaultsToOnce() async throws {
//        enum Err: Error, Equatable {
//            case e1
//        }
//        actor Test {
//            var arr = [String]()
//            func append(_ str: String) {
//                arr.append(str)
//            }
//        }
//
//        let test = Test()
//
//        let t = Task {
//            try await DeferredTask {
//                await test.append("called")
//            }
//            .toAsyncSequence()
//            .map { _ in throw Err.e1 }
//            .retry(on: Err.e1)
//            .first()
//        }
//
//        _ = await t.result
//
//        let copy = await test.arr
//        #expect(UInt(copy.count) == 2)
//    }
//
//    @Test func taskCanRetryWithoutError_DoesNothing() async throws {
//        enum Err: Error, Equatable {
//            case e1
//        }
//        actor Test {
//            var arr = [String]()
//            func append(_ str: String) {
//                arr.append(str)
//            }
//        }
//
//        let test = Test()
//
//        let t = Task {
//            try await DeferredTask {
//                await test.append("called")
//            }
//            .toAsyncSequence()
//            .retry(10, on: Err.e1)
//            .first()
//        }
//
//        _ = await t.result
//
//        let copy = await test.arr
//        #expect(UInt(copy.count) == 1)
//    }
//}
