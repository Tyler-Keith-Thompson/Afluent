//
//  KeyPathExtensions.swift
//
//
//  Created by Tyler Thompson on 3/31/24.
//

import Foundation

// https://forums.swift.org/t/sendablekeypath/67195
extension KeyPath: @unchecked @retroactive Sendable where Value: Sendable { }
