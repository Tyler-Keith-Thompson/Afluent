//
//  MeasurementExtensions.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Foundation

extension Measurement<UnitDuration> {
    public static func hours(_ value: Double) -> Measurement<UnitDuration> {
        .init(value: value, unit: .hours)
    }

    public static func minutes(_ value: Double) -> Measurement<UnitDuration> {
        .init(value: value, unit: .minutes)
    }
    
    public static func seconds(_ value: Double) -> Measurement<UnitDuration> {
        .init(value: value, unit: .seconds)
    }
    
    public static func milliseconds(_ value: Double) -> Measurement<UnitDuration> {
        .init(value: value, unit: .milliseconds)
    }

    public static func microseconds(_ value: Double) -> Measurement<UnitDuration> {
        .init(value: value, unit: .microseconds)
    }

    public static func nanoseconds(_ value: Double) -> Measurement<UnitDuration> {
        .init(value: value, unit: .nanoseconds)
    }

    public static func picoseconds(_ value: Double) -> Measurement<UnitDuration> {
        .init(value: value, unit: .picoseconds)
    }
}
