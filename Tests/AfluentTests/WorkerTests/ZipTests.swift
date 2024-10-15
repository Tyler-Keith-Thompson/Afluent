//
//  ZipTests.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Afluent
import Foundation
import Testing

struct ZipTests {
    @Test func zipCombinesTasks_WithExplicitFailure() async throws {
        let t1 = DeferredTask<Int> { 1 }

        let t2 = DeferredTask<String> { "A" }
        let t3 = t2.zip(t1)
        let val = try await t3.execute()  // Steak sauce!!!
        #expect(val.0 == "A")
        #expect(val.1 == 1)
    }

    @Test func zipCombinesTasks() async throws {
        let t1 = DeferredTask { 1 }

        let t2 = DeferredTask { "A" }
        let t3 = t2.zip(t1)
        let val = try await t3.execute()  // Steak sauce!!!
        #expect(val.0 == "A")
        #expect(val.1 == 1)
    }

    @Test func zipTransformCombinesTasks_WithExplicitFailure() async throws {
        let t1 = DeferredTask<Int> { 1 }

        let t2 = DeferredTask<String> { "A" }
        let t3 = t2.zip(t1) { $0 + String(describing: $1) }
        let val = try await t3.execute()  // Steak sauce!!!
        #expect(val == "A1")
    }

    @Test func zipTransformCombinesTasks() async throws {
        let t1 = DeferredTask { 1 }

        let t2 = DeferredTask { "A" }
        let t3 = t2.zip(t1) { $0 + String(describing: $1) }
        let val = try await t3.execute()  // Steak sauce!!!
        #expect(val == "A1")
    }

    @Test func zip3CombinesTasks_WithExplicitFailure() async throws {
        let t1 = DeferredTask<Int> { 1 }
        let t2 = DeferredTask<String> { "A" }
        let t3 = DeferredTask<Bool> { true }

        let t4 = t2.zip(t1, t3)
        let val = try await t4.execute()  // Steak sauce!!!
        #expect(val.0 == "A")
        #expect(val.1 == 1)
        #expect(val.2 == true)
    }

    @Test func zip3CombinesTasks() async throws {
        let t1 = DeferredTask { 1 }
        let t2 = DeferredTask { "A" }
        let t3 = DeferredTask { true }

        let t4 = t2.zip(t1, t3)
        let val = try await t4.execute()  // Steak sauce!!!
        #expect(val.0 == "A")
        #expect(val.1 == 1)
        #expect(val.2 == true)
    }

    @Test func zip3TransformCombinesTasks_WithExplicitFailure() async throws {
        let t1 = DeferredTask<Int> { 1 }
        let t2 = DeferredTask<String> { "A" }
        let t3 = DeferredTask<Bool> { true }

        let t4 = t2.zip(t1, t3) { $0 + String(describing: $1) + String(describing: $2) }
        let val = try await t4.execute()  // Steak sauce!!!
        #expect(val == "A1true")
    }

    @Test func zip3TransformCombinesTasks() async throws {
        let t1 = DeferredTask { 1 }
        let t2 = DeferredTask { "A" }
        let t3 = DeferredTask { true }

        let t4 = t2.zip(t1, t3) { $0 + String(describing: $1) + String(describing: $2) }
        let val = try await t4.execute()  // Steak sauce!!!
        #expect(val == "A1true")
    }

    @Test func zip4CombinesTasks_WithExplicitFailure() async throws {
        let t1 = DeferredTask<Int> { 1 }
        let t2 = DeferredTask<String> { "A" }
        let t3 = DeferredTask<Bool> { true }
        let t4 = DeferredTask<Character> { Character("!") }

        let t5 = t2.zip(t1, t3, t4)
        let val = try await t5.execute()  // Steak sauce!!!
        #expect(val.0 == "A")
        #expect(val.1 == 1)
        #expect(val.2 == true)
        #expect(val.3 == Character("!"))
    }

    @Test func zip4CombinesTasks() async throws {
        let t1 = DeferredTask { 1 }
        let t2 = DeferredTask { "A" }
        let t3 = DeferredTask { true }
        let t4 = DeferredTask { Character("!") }

        let t5 = t2.zip(t1, t3, t4)
        let val = try await t5.execute()  // Steak sauce!!!
        #expect(val.0 == "A")
        #expect(val.1 == 1)
        #expect(val.2 == true)
        #expect(val.3 == Character("!"))
    }

    @Test func zip4TransformCombinesTasks_WithExplicitFailure() async throws {
        let t1 = DeferredTask<Int> { 1 }
        let t2 = DeferredTask<String> { "A" }
        let t3 = DeferredTask<Bool> { true }
        let t4 = DeferredTask<Character> { Character("!") }

        let t5 = t2.zip(t1, t3, t4) {
            $0 + String(describing: $1) + String(describing: $2) + String(describing: $3)
        }
        let val = try await t5.execute()  // Steak sauce!!!
        #expect(val == "A1true!")
    }

    @Test func zip4TransformCombinesTasks() async throws {
        let t1 = DeferredTask { 1 }
        let t2 = DeferredTask { "A" }
        let t3 = DeferredTask { true }
        let t4 = DeferredTask { Character("!") }

        let t5 = t2.zip(t1, t3, t4) {
            $0 + String(describing: $1) + String(describing: $2) + String(describing: $3)
        }
        let val = try await t5.execute()  // Steak sauce!!!
        #expect(val == "A1true!")
    }
}
