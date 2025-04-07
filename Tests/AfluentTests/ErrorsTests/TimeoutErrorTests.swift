//
//  TimeoutErrorTests.swift
//  Afluent
//
//  Created by Dalton Alexandre on 4/5/25.
//


import Testing
@testable import Afluent

struct TimeoutErrorTests {
    @Test func testTimeoutErrorEquality() async {
        let error1 = TimeoutError.timedOut(duration: Duration.seconds(5))
        let error2 = TimeoutError.timedOut(duration: Duration.seconds(10))
        #expect(error1 == error2, "TimeoutError equality should not depend on duration")
    }

    @Test func testTimeoutErrorDescription() async {
        let duration = Duration.seconds(3)
        let error = TimeoutError.timedOut(duration: duration)
        let description = #require(error.errorDescription)
        #expect(description == "Timed out after waiting \(duration)")
    }

    @Test func testStaticTimedOutIsZeroDuration() async {
        let staticTimeout: TimeoutError = .timedOut
        #expect(staticTimeout == TimeoutError.timedOut(duration: Duration.zero))
    }
}
