//
//  SingleValueChannelTests.swift
//
//
//  Created by Tyler Thompson on 11/11/23.
//

import Afluent
import Foundation
import XCTest

final class SingleValueChannelTests: XCTestCase {
    func testSingleValueSubjectEmittingValueBeforeTaskRuns() async throws {
        let expected = Int.random(in: 1 ... 1000)
        let exp = expectation(description: "task executed")
        let subject = SingleValueChannel<Int>()
        let unitOfWork = subject.map {
            exp.fulfill()
            return $0
        }

        try await subject.send(expected)

        let actual = try await unitOfWork.execute()
        await fulfillment(of: [exp], timeout: 0)
        XCTAssertEqual(actual, expected)
    }

    func testSingleValueSubjectEmittingValueAfterTaskRuns() async throws {
        let expected = Int.random(in: 1 ... 1000)
        let exp = expectation(description: "task executed")
        let subject = SingleValueChannel<Int>()
        subject.map {
            exp.fulfill()
            XCTAssertEqual($0, expected)
            return $0
        }.run() // task started

        try await subject.send(expected)

        await fulfillment(of: [exp], timeout: 0.01)
    }

    func testSingleValueSubjectEmittingErrorBeforeTaskRuns() async throws {
        enum Err: Error { case e1 }
        let subject = SingleValueChannel<Int>()

        try await subject.send(error: Err.e1)

        let actualResult = try await subject.result
        XCTAssertThrowsError(try actualResult.get()) { error in
            XCTAssertEqual(error as? Err, .e1)
        }
    }

    func testSingleValueSubjectEmittingErrorAfterTaskRuns() async throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] == "true")

        enum Err: Error { case e1 }
        let exp = expectation(description: "task executed")
        let subject = SingleValueChannel<Int>()
        let unitOfWork = subject
            .materialize()
            .map {
                exp.fulfill()
                return $0
            }

        Task {
            try await Task.sleep(nanoseconds: UInt64(Measurement<UnitDuration>.milliseconds(10).converted(to: .nanoseconds).value))
            try await subject.send(error: Err.e1)
        }

        let actualResult = try await unitOfWork.execute()
        XCTAssertThrowsError(try actualResult.get()) { error in
            XCTAssertEqual(error as? Err, .e1)
        }

        await fulfillment(of: [exp], timeout: 0.01)
    }

    func testSingleValueSubjectOnlyEmitsValueOnce() async throws {
        let expected = Int.random(in: 1 ... 1000)
        let exp = expectation(description: "task executed")
        let subject = SingleValueChannel<Int>()
        subject.map {
            exp.fulfill()
            XCTAssertEqual($0, expected)
            return $0
        }.run() // task started

        try await subject.send(expected)
        let result = await Task { try await subject.send(expected) }.result
        XCTAssertThrowsError(try result.get())

        await fulfillment(of: [exp], timeout: 0.01)
    }

    func testSingleValueSubjectOnlyEmitsErrorOnce() async throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] == "true")

        enum Err: Error { case e1 }
        let exp = expectation(description: "task executed")
        let exp1 = expectation(description: "Subject error sent")
        let subject = SingleValueChannel<Int>()
        let unitOfWork = subject
            .materialize()
            .map {
                exp.fulfill()
                return $0
            }

        Task {
            try await Task.sleep(nanoseconds: UInt64(Measurement<UnitDuration>.milliseconds(10).converted(to: .nanoseconds).value))
            try await subject.send(error: Err.e1)

            let result = await Task { try await subject.send(error: Err.e1) }.result
            XCTAssertThrowsError(try result.get())
            exp1.fulfill()
        }

        let actualResult = try await unitOfWork.execute()
        XCTAssertThrowsError(try actualResult.get()) { error in
            XCTAssertEqual(error as? Err, .e1)
        }

        await fulfillment(of: [exp, exp1], timeout: 0.01)
    }

    func testVoidSingleValueSubjectEmittingValueBeforeTaskRuns() async throws {
        let exp = expectation(description: "task executed")
        let subject = SingleValueChannel<Void>()
        let unitOfWork = subject.map {
            exp.fulfill()
        }

        try await subject.send()

        try await unitOfWork.execute()

        await fulfillment(of: [exp], timeout: 0)
    }

    func testVoidSingleValueSubjectEmittingValueAfterTaskRuns() async throws {
        let exp = expectation(description: "task executed")
        let subject = SingleValueChannel<Void>()
        subject.map {
            exp.fulfill()
        }.run() // task started

        try await subject.send()

        await fulfillment(of: [exp], timeout: 0.01)
    }
}
