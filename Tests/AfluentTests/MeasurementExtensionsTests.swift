//
//  MeasurementExtensionsTests.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Afluent
import Foundation
import XCTest

final class MeasurementExtensionsTests: XCTestCase {
    func testHoursMeasurement() {
        XCTAssertEqual(Measurement<UnitDuration>(value: 10, unit: .hours), .hours(10))
    }

    func testMinutesMeasurement() {
        XCTAssertEqual(Measurement<UnitDuration>(value: 10, unit: .minutes), .minutes(10))
    }

    func testSecondsMeasurement() {
        XCTAssertEqual(Measurement<UnitDuration>(value: 10, unit: .seconds), .seconds(10))
    }

    func testMillisecondsMeasurement() {
        XCTAssertEqual(Measurement<UnitDuration>(value: 10, unit: .milliseconds), .milliseconds(10))
    }

    func testMicrosecondsMeasurement() {
        XCTAssertEqual(Measurement<UnitDuration>(value: 10, unit: .microseconds), .microseconds(10))
    }

    func testNanosecondsMeasurement() {
        XCTAssertEqual(Measurement<UnitDuration>(value: 10, unit: .nanoseconds), .nanoseconds(10))
    }

    func testPicosecondsMeasurement() {
        XCTAssertEqual(Measurement<UnitDuration>(value: 10, unit: .picoseconds), .picoseconds(10))
    }
}
