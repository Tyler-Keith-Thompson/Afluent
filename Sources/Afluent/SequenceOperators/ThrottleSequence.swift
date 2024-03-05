//
//  ThrottleSequence.swift
//
//
//  Created by Trip Phillips on 2/12/24.
//

import Foundation

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension AsyncSequences {
    public struct Throttle<Upstream: AsyncSequence, C: Clock>: AsyncSequence {
        public typealias Element = Upstream.Element
        let upstream: Upstream
        let interval: C.Duration
        let clock: C
        let latest: Bool
        
        class IntervalEvents {
            var hasSeenFirstElement: Bool
            var hasStartedInterval: Bool
            var firstElement: Element?
            var latestElement: Element?
            var startInstant: C.Instant?
            
            private let lock = NSRecursiveLock()
            
            init(hasSeenFirstElement: Bool = false,
                 hasStartedInterval: Bool = false,
                 firstElement: Element? = nil,
                 latestElement: Element? = nil,
                 startInstant: C.Instant? = nil) {
                self.hasSeenFirstElement = hasSeenFirstElement
                self.hasStartedInterval = hasStartedInterval
                self.firstElement = firstElement
                self.latestElement = latestElement
                self.startInstant = startInstant
            }
            
            func updateHasSeenFirstElement() {
                lock.protect {
                    hasSeenFirstElement = true
                }
            }
            
            func updateHasStartedInterval(_ hasStarted: Bool) {
                lock.protect {
                    hasStartedInterval = hasStarted
                }
            }
            
            func updateFirst(element: Element?) {
                lock.protect {
                    firstElement = element
                }
            }
            
            func updateLatest(element: Element?) {
                lock.protect {
                    latestElement = element
                }
            }
            
            func updateStart(instant: C.Instant) {
                lock.protect {
                    startInstant = instant
                }
            }
        }
        
        public struct AsyncIterator: AsyncIteratorProtocol {
            typealias Instant = C.Instant
            
            var upstream: Upstream
            let interval: C.Duration
            let clock: C
            let latest: Bool
            
            var iterator: AsyncThrowingStream<(Element?, Element?), Error>.Iterator?
            let intervalEvents = IntervalEvents()
            
            public mutating func next() async throws -> Element? {
                try Task.checkCancellation()
                
                let clock = self.clock
                let interval = self.interval
                let upstream = self.upstream
                let intervalEvents = self.intervalEvents
                
                if iterator == nil {
                    self.iterator = AsyncThrowingStream<(Element?, Element?), Error> { continuation in
                        
                        let intervalTask = DeferredTask {
                            if let intervalStartInstant = intervalEvents.startInstant {
                                intervalEvents.updateHasStartedInterval(true)
                                
                                let intervalEndInstant = intervalStartInstant.advanced(by: interval)
                                try await clock.sleep(until: intervalEndInstant, tolerance: nil)
                                
                                let firstElement = intervalEvents.firstElement
                                let latestElement = intervalEvents.latestElement
                                
                                continuation.yield((firstElement, latestElement))
                                
                                intervalEvents.updateFirst(element: nil)
                                intervalEvents.updateHasStartedInterval(false)
                            }
                        }
                        
                        Task {
                            do {
                                for try await el in upstream {
                                    if !intervalEvents.hasSeenFirstElement {
                                        continuation.yield((el, el))
                                        intervalEvents.updateHasSeenFirstElement()
                                        continue
                                    }
                                    if intervalEvents.firstElement == nil {
                                        intervalEvents.updateStart(instant: clock.now)
                                        intervalEvents.updateFirst(element: el)
                                        intervalTask.run()
                                    }
                                    intervalEvents.updateLatest(element: el)
                                }
                                if intervalEvents.hasStartedInterval {
                                    continuation.yield((intervalEvents.firstElement, intervalEvents.latestElement))
                                }
                                continuation.finish()
                            } catch {
                                continuation.yield((intervalEvents.firstElement, intervalEvents.latestElement))
                                continuation.finish(throwing: error)
                            }
                        }
                        
                        continuation.onTermination = { _ in
                            intervalTask.cancel()
                        }
                        
                    }.makeAsyncIterator()
                }
                
                while let (firstElement, latestElement) = try await self.iterator?.next() {
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

@available(iOS 16.0, *)
extension AsyncSequence {
    /// Emits either the first or latest element received during a specified amount of time.
    /// - Parameter interval: The interval of time in which to observe and emit either the first or latest element.
    /// - Parameter latest: If `true`, emits the latest element in the time interval.  If `false`, emits the first element in the time interval.
    /// - Note: The first element in upstream will always be returned immediately.  Once a second element is received, then the clock will begin for the given time interval and return the first or latest element once completed.
    public func throttle<C: Clock>(for interval: C.Duration, clock: C, latest: Bool = false) -> AsyncSequences.Throttle<Self, C> {
        AsyncSequences.Throttle(upstream: self, interval: interval, clock: clock, latest: latest)
    }
}
