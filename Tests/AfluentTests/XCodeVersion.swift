//
//  XCodeVersion.swift
//
//
//  Created by Tyler Thompson on 6/15/24.
//

enum XcodeVersion {
    case v16
    case v15

    static var current: XcodeVersion {
        #if swift(>=6)
            return .v16
        #else
            return .v15
        #endif
    }
}
