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
            var latestElement: Element?
            var startInstant: C.Instant?
            
            init(firstElement: Element? = nil, 
                 latestElement: Element? = nil,
                 startInstant: C.Instant? = nil) {
                self.firstElement = firstElement
                self.latestElement = latestElement
                self.startInstant = startInstant
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
                    let intervalEvents = IntervalEvents(startInstant: clock.now)
                    
                    let intervalTask = DeferredTask {
                        if let intervalStartInstant = await intervalEvents.startInstant {
                            let firstElement = await intervalEvents.firstElement
                            let latestElement = await intervalEvents.latestElement
                            
                            // I think there is a race condition because if you don't use different sleep methods for latest, the updated lastElement won't return after being updated a few milliseconds before.  Instead the previous element will return.  We can get around this for now by using 2 different sleep methods.
                            if latest {
                                try await clock.sleep(for: interval, tolerance: nil)
                            } else {
                                let intervalEndInstant = intervalStartInstant.advanced(by: interval)
                                try await clock.sleep(until: intervalEndInstant, tolerance: nil)
                            }
                            
                            continuation.yield((firstElement, latestElement))
                            await intervalEvents.updateFirst(element: nil)
                            
                            await intervalEvents.updateStart(instant: clock.now)
                        }
                    }
                    
                    Task {
                        do {
                            for try await el in upstream {
                                if await intervalEvents.firstElement == nil {
                                    intervalTask.run()
                                    await intervalEvents.updateFirst(element: el)
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
