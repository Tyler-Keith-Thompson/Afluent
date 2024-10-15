//
//  KeyPathExtensions.swift
//
//
//  Created by Tyler Thompson on 3/31/24.
//

import Foundation

#if swift(<6)
    extension KeyPath: @unchecked Sendable where Value: Sendable {}
#else
    // https://forums.swift.org/t/sendablekeypath/67195
    extension KeyPath: @unchecked @retroactive Sendable where Value: Sendable {}
#endif
