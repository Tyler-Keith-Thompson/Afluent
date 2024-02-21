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
        
        actor IntervalEvents {
            var hasSeenFirstElement: Bool
            var hasCompletedFirstInterval: Bool
            var firstElement: Element?
            var latestElement: Element?
            var startInstant: C.Instant?
            
            init(hasSeenFirstElement: Bool = false,
                 hasCompletedFirstInterval: Bool = false,
                 firstElement: Element? = nil,
                 latestElement: Element? = nil,
                 startInstant: C.Instant? = nil) {
                self.hasSeenFirstElement = hasSeenFirstElement
                self.hasCompletedFirstInterval = hasCompletedFirstInterval
                self.firstElement = firstElement
                self.latestElement = latestElement
                self.startInstant = startInstant
            }
        
            func updateHasSeenFirstElement() {
                hasSeenFirstElement = true
            }
            
            func updateHasCompletedFirstInterval() {
                hasCompletedFirstInterval = true
            }
            
            func updateFirst(element: Element?) {
                firstElement = element
            }
            
            func updateLatest(element: Element?) {
                latestElement = element
            }
            
            func updateStart(instant: C.Instant) {
                startInstant = instant
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
                        if let intervalStartInstant = await intervalEvents.startInstant {
                          
                            let intervalEndInstant = intervalStartInstant.advanced(by: interval)
                        
                            try await clock.sleep(until: intervalEndInstant, tolerance: nil)
                            
                            let firstElement = await intervalEvents.firstElement
                            let latestElement = await intervalEvents.latestElement
                            
                            continuation.yield((firstElement, latestElement))
                            
                            if await intervalEvents.hasCompletedFirstInterval {
                                await intervalEvents.updateHasCompletedFirstInterval()
                            }
                            
                            await intervalEvents.updateFirst(element: nil)
                        }
                    }
                    
                    Task {
                        do {
                            for try await el in upstream {
                                if await !intervalEvents.hasSeenFirstElement {
                                        
                                    continuation.yield((el, el))
                                    await intervalEvents.updateHasSeenFirstElement()
                                    continue
                                }
                                
                                if await intervalEvents.firstElement == nil {
                                    await intervalEvents.updateStart(instant: clock.now)
                                    await intervalEvents.updateFirst(element: el)
                                    
                                    intervalTask.run()
                                }
                                
                                await intervalEvents.updateLatest(element: el)
                            }
                            await continuation.yield((intervalEvents.firstElement, intervalEvents.latestElement))
                            
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
