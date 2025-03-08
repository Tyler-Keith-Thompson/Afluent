//
//  ArrayExtensions.swift
//  Afluent
//
//  Created by Roman Temchenko on 2025-03-07.
//

import Foundation

extension Array where Element: Sendable {
    var async: AsyncStream<Element> {
        AsyncStream<Element> {
            for item in self {
                $0.yield(item)
            }
            $0.finish()
        }
    }
}
