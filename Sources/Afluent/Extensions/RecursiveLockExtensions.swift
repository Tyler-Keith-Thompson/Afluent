//
//  RecursiveLockExtensions.swift
//
//
//  Created by Tyler Thompson on 11/10/23.
//

import Foundation

extension NSRecursiveLock {
    func protect<T>(_ instructions: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try instructions()
    }
}
