//
//  ThrottleSequence.swift
//
//
//  Created by Trip Phillips on 2/12/24.
//

import Foundation

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
extension AsyncSequences {
    public struct Throttle<Upstream: AsyncSequence & Sendable, C: Clock>: AsyncSequence {
        public typealias Element = Upstream.Element
        let upstream: Upstream
        let interval: C.Duration
        let clock: C
        let latest: Bool

        public struct AsyncIterator: AsyncIteratorProtocol {
            typealias Instant = C.Instant

            var upstream: Upstream
            let interval: C.Duration
            let clock: C
            let latest: Bool

            var iterator: AsyncThrowingStream<(Element?, Element?), Error>.Iterator?
            let state = State()

            public mutating func next() async throws -> Element? {
                try Task.checkCancellation()

                if iterator == nil {
                    iterator = AsyncThrowingStream<(Element?, Element?), Error> { [clock, interval, upstream, state] continuation in

                        let intervalTask = DeferredTask {
                            guard let intervalStartInstant = state.startInstant else { return }
                            state.hasStartedInterval = true

                            let intervalEndInstant = intervalStartInstant.advanced(by: interval)
                            try await clock.sleep(until: intervalEndInstant, tolerance: nil)

                            let firstElement = state.firstElement
                            let latestElement = state.latestElement

                            continuation.yield((firstElement, latestElement))

                            state.firstElement = nil
                            state.hasStartedInterval = false
                        }

                        let iterationTask = Task {
                            do {
                                try Task.checkCancellation()
                                for try await el in upstream {
                                    try Task.checkCancellation()
                                    if !state.hasSeenFirstElement {
                                        continuation.yield((el, el))
                                        state.hasSeenFirstElement = true
                                        continue
                                    }
                                    if state.firstElement == nil {
                                        state.startInstant = clock.now
                                        state.firstElement = el
                                        intervalTask.run()
                                    }
                                    state.latestElement = el
                                }
                                if state.hasStartedInterval {
                                    continuation.yield((state.firstElement, state.latestElement))
                                }
                                continuation.finish()
                            } catch {
                                if state.hasStartedInterval {
                                    continuation.yield((state.firstElement, state.latestElement))
                                }
                                continuation.finish(throwing: error)
                            }
                        }

                        continuation.onTermination = { _ in
                            // Clean up any running tasks if the upstream is terminated.
                            // We are unable to write a test to specifically target this behavior but it should be kept in place to ensure there are no breaking edge cases.
                            intervalTask.cancel()
                            iterationTask.cancel()
                        }

                    }.makeAsyncIterator()
                }

                while let (firstElement, latestElement) = try await iterator?.next() {
                    try Task.checkCancellation()
                    return latest ? latestElement : firstElement
                }

                return nil
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(upstream: upstream, interval: interval, clock: clock, latest: latest)
        }
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
extension AsyncSequence where Self: Sendable {
    /// Emits either the first or latest element received during a specified amount of time.
    /// - Parameter interval: The interval of time in which to observe and emit either the first or latest element.
    /// - Parameter latest: If `true`, emits the latest element in the time interval.  If `false`, emits the first element in the time interval.
    /// - Note: The first element in upstream will always be returned immediately.  Once a second element is received, then the clock will begin for the given time interval and return the first or latest element once completed.
    public func throttle<C: Clock>(for interval: C.Duration, clock: C, latest: Bool) -> AsyncSequences.Throttle<Self, C> {
        AsyncSequences.Throttle(upstream: self, interval: interval, clock: clock, latest: latest)
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
extension AsyncSequences.Throttle {
    class State: @unchecked Sendable {
        private var _hasSeenFirstElement: Bool = false
        var hasSeenFirstElement: Bool {
            get { lock.protect { _hasSeenFirstElement } }
            set { lock.protect { _hasSeenFirstElement = newValue } }
        }

        private var _hasStartedInterval: Bool = false
        var hasStartedInterval: Bool {
            get { lock.protect { _hasStartedInterval } }
            set { lock.protect { _hasStartedInterval = newValue } }
        }

        private var _firstElement: Element?
        var firstElement: Element? {
            get { lock.protect { _firstElement } }
            set { lock.protect { _firstElement = newValue } }
        }

        private var _latestElement: Element?
        var latestElement: Element? {
            get { lock.protect { _latestElement } }
            set { lock.protect { _latestElement = newValue } }
        }

        private var _startInstant: C.Instant?
        var startInstant: C.Instant? {
            get { lock.protect { _startInstant } }
            set { lock.protect { _startInstant = newValue } }
        }

        private let lock = NSRecursiveLock()
    }
}
