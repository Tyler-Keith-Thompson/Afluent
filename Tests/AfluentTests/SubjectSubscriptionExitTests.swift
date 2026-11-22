//
//  SubjectSubscriptionExitTests.swift
//  Afluent
//

// Exit tests start a child process, which only these platforms can.
#if os(macOS) || os(Linux) || os(Windows)
    import Afluent
    import Foundation
    import Testing

    struct SubjectSubscriptionExitTests {
        @Test("Calling next() while another call on the same subscription is waiting traps")
        func concurrentWaitsTrap() async {
            await #expect(processExitsWith: .failure) {
                let subject = PassthroughSubject<Int>()
                let subscription = subject.makeSubscription()
                // Nothing is ever sent, so both calls stay waiting and whichever registers second traps.
                async let first = subscription.next()
                async let second = subscription.next()
                _ = try await (first, second)
            }
        }
    }
#endif
