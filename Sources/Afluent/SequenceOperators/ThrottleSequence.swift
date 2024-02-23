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
            var firstElement: Element?
            var latestElement: Element?
            var startInstant: C.Instant?

            private let lock = NSRecursiveLock()
            
            init(hasSeenFirstElement: Bool = false,
                 firstElement: Element? = nil,
                 latestElement: Element? = nil,
                 startInstant: C.Instant? = nil) {
                self.hasSeenFirstElement = hasSeenFirstElement
                self.firstElement = firstElement
                self.latestElement = latestElement
                self.startInstant = startInstant
            }
        
            func updateHasSeenFirstElement() {
                lock.protect {
                    hasSeenFirstElement = true
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
            
            let upstream: Upstream
            let interval: C.Duration
            var iterator: AsyncThrowingStream<(Element?, Element?), Error>.Iterator
            let clock: C
            let latest: Bool
            
            init(upstream: Upstream,
                 interval: C.Duration,
                 clock: C,
                 latest: Bool) {
                self.upstream = upstream
                self.interval = interval
                self.clock = clock
                self.latest = latest
                let stream = AsyncThrowingStream<(Element?, Element?), Error> { continuation in
                    
                    let intervalEvents = IntervalEvents()
                    
                    let intervalTask = DeferredTask {
                        if let intervalStartInstant = intervalEvents.startInstant {
                          
                            let intervalEndInstant = intervalStartInstant.advanced(by: interval)
                        
                            try await clock.sleep(until: intervalEndInstant, tolerance: nil)
                            
                            let firstElement = intervalEvents.firstElement
                            let latestElement = intervalEvents.latestElement
                            
                            continuation.yield((firstElement, latestElement))
                            
                            intervalEvents.updateFirst(element: nil)
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
                            continuation.yield((intervalEvents.firstElement, intervalEvents.latestElement))
                            
                            intervalTask.cancel()
                            continuation.finish()
                        } catch {
                            intervalTask.cancel()
                            continuation.finish(throwing: error)
                        }
                    }
                }
                iterator = stream.makeAsyncIterator()
            }
            
            public mutating func next() async throws -> Element? {
                try Task.checkCancellation()
                while let (firstElement, latestElement) = try await iterator.next() {
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
    public func throttle<C: Clock>(for interval: C.Duration, clock: C, latest: Bool = false) -> AsyncSequences.Throttle<Self, C> {
        AsyncSequences.Throttle(upstream: self, interval: interval, clock: clock, latest: latest)
    }
}
