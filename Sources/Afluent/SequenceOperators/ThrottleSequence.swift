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
            var hasSeenSecondElement: Bool
            var isRunningIntervalTask: Bool
            var firstElement: Element?
            var latestElement: Element?
            var startInstant: C.Instant?
            
            private let lock = NSRecursiveLock()
            
            init(hasSeenFirstElement: Bool = false,
                 hasSeenSecondElement: Bool = false,
                 isRunningIntervalTask: Bool = false,
                 firstElement: Element? = nil,
                 latestElement: Element? = nil,
                 startInstant: C.Instant? = nil) {
                self.hasSeenFirstElement = hasSeenFirstElement
                self.hasSeenSecondElement = hasSeenSecondElement
                self.isRunningIntervalTask = isRunningIntervalTask
                self.firstElement = firstElement
                self.latestElement = latestElement
                self.startInstant = startInstant
            }
            
            func updateHasSeenFirstElement() {
                lock.protect {
                    hasSeenFirstElement = true
                }
            }
            
            func updateHasSeenSecondElement() {
                lock.protect {
                    hasSeenSecondElement = true
                }
            }
            
            func updateIsRunningIntervalTask(_ isRunning: Bool) {
                lock.protect {
                    isRunningIntervalTask = isRunning
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
            
            var upstreamIterator: Upstream.AsyncIterator
            let interval: C.Duration
            let clock: C
            let latest: Bool

            let intervalEvents = IntervalEvents()
            
            public mutating func next() async throws -> Element? {
                try Task.checkCancellation()
                
                let intervalEvents = self.intervalEvents
                let clock = self.clock
                let latest = self.latest
                let interval = self.interval
                
                let intervalTask = DeferredTask {
                    
                    guard let intervalEndInstant = intervalEvents.startInstant?.advanced(by: interval) else {
                        return
                    }
                
                    try await clock.sleep(until: intervalEndInstant, tolerance: .zero)
                    
                    intervalEvents.updateIsRunningIntervalTask(false)
                }
                
                repeat {
                    
                    guard let element = try await upstreamIterator.next() else {
                        intervalTask.cancel()
                        return nil
                    }
                    
                    if !intervalEvents.hasSeenFirstElement {
                        intervalEvents.updateHasSeenFirstElement()
                        return element
                    }
                    
                    if intervalEvents.firstElement == nil {
                        intervalEvents.updateStart(instant: clock.now)
                        intervalEvents.updateFirst(element: element)
                    }
                    
                    intervalEvents.updateLatest(element: element)

                    if !intervalEvents.isRunningIntervalTask {
                        let firstElement = intervalEvents.firstElement
                        let latestElement = intervalEvents.latestElement
                        intervalEvents.updateFirst(element: nil)
                        intervalEvents.updateIsRunningIntervalTask(true)
                        intervalTask.run()
                        return latest ? latestElement : firstElement
                    }
                    
                } while true
            }
        }
        
        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(upstreamIterator: upstream.makeAsyncIterator(), interval: interval, clock: clock, latest: latest)
        }
    }
}

@available(iOS 16.0, *)
extension AsyncSequence {
    public func throttle<C: Clock>(for interval: C.Duration, clock: C, latest: Bool = false) -> AsyncSequences.Throttle<Self, C> {
        AsyncSequences.Throttle(upstream: self, interval: interval, clock: clock, latest: latest)
    }
}
