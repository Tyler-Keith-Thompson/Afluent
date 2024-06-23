//
//  DelayTests.swift
//
//
//  Created by Tyler Thompson on 10/27/23.
//

import Afluent
import Clocks
import Foundation
import Testing

struct DelayTests {
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
    @Test func deferredTaskCanDelayForAnExpectedDuration() async throws {
        actor Test {
            var finished = false
            func setFinished(_ val: Bool) {
                finished = val
            }
        }
        let clock = TestClock()
        let test = Test()
        DeferredTask { }
            .delay(for: .milliseconds(10), clock: clock, tolerance: nil)
            .handleEvents(receiveOutput: { _ in await test.setFinished(true) })
            .run()

        await clock.advance(by: .milliseconds(1))
        let finished1 = await test.finished
        #expect(!finished1)
        await clock.advance(by: .milliseconds(9))
        let finished2 = await test.finished
        #expect(finished2)
    }
}
