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
            var firstElement: Element?
            var lastElement: Element?
            var lastElementInstant: C.Instant?
            var intervalStartInstant: C.Instant?
            
            init(firstElement: Element? = nil, 
                 lastElement: Element? = nil,
                 lastElementInstant: C.Instant? = nil,
                 intervalStartInstant: C.Instant? = nil) {
                self.firstElement = firstElement
                self.lastElement = lastElement
                self.lastElementInstant = lastElementInstant
                self.intervalStartInstant = intervalStartInstant
            }
        
            func updateFirstElement(_ element: Element?, instant: C.Instant) {
                firstElement = element
                lastElementInstant = instant
            }
            
            func updateLastElement(_ element: Element?, instant: C.Instant) {
                lastElement = element
                lastElementInstant = instant
            }
            
            func updateIntervalStartInstant(_ instant: C.Instant) {
                intervalStartInstant = instant
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
                    
                    // Need a task to run and save the first and last element of all elements from iterators.
                    
                    // Need a task to listen for the current time interval.
                    
                    
                    let intervalEvents = IntervalEvents(firstElement: nil, lastElement: nil, intervalStartInstant: clock.now)
                    
                    let intervalTask = DeferredTask {
                        Swift.print("RUN")
                       
                            if let intervalStartInstant = await intervalEvents.intervalStartInstant {
                                let firstElement = await intervalEvents.firstElement
                                let lastElement = await intervalEvents.lastElement
                                
                                let intervalEndInstant = intervalStartInstant.advanced(by: interval)
                                Swift.print("SLEEP: \(intervalEndInstant)")
                                
                                try await clock.sleep(until: intervalEndInstant, tolerance: nil)
                                
                                Swift.print("YIELD")
                                Swift.print("FIRST: \(firstElement)")
                                Swift.print("LAST: \(lastElement)")
                                continuation.yield((firstElement, lastElement))
                                await intervalEvents.updateFirstElement(nil, instant: clock.now)
                                //await intervalEvents.updateLastElement(nil, instant: clock.now)
                                
                                await intervalEvents.updateIntervalStartInstant(clock.now)
                            } else {
                                Swift.print("NO START!!")
                            }
                    }
                    
                    Task {
                        do {
                            for try await el in upstream {
                                if await intervalEvents.firstElement == nil {
                                    intervalTask.run()
                                    await intervalEvents.updateFirstElement(el, instant: clock.now)
                                    Swift.print("UPDATE First: \(el)")
                                }
                                await intervalEvents.updateLastElement(el, instant: clock.now)
                                Swift.print("UPDATE Last: \(el)")
                            }
                            await continuation.yield((intervalEvents.firstElement, intervalEvents.lastElement))
                            Swift.print("----FINISH----")
                            intervalTask.cancel()
                            continuation.finish()
                        } catch {
                            continuation.finish(throwing: error)
                        }
                    }
                }
                iterator = stream.makeAsyncIterator()
            }
            
            public mutating func next() async throws -> Element? {
                try Task.checkCancellation()
                while let (first, last) = try await iterator.next() {
                    return latest ? last : first
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
