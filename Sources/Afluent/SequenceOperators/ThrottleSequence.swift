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
        
        public struct AsyncIterator: AsyncIteratorProtocol {
            typealias Instant = C.Instant
            
            let upstream: Upstream
            let interval: C.Duration
            var iterator: AsyncThrowingStream<(Instant, Element), Error>.Iterator
            let clock: C
            let latest: Bool
            
            private var firstIntervalInstant: C.Instant?
            private var firstElement: Element?
            private var lastElement: Element?
            
            init(upstream: Upstream,
                 interval: C.Duration,
                 clock: C,
                 latest: Bool) {
                self.upstream = upstream
                self.interval = interval
                self.clock = clock
                self.latest = latest
                let stream = AsyncThrowingStream<(Instant, Element), Error> { continuation in
                    Task {
                        do {
                            for try await el in upstream {
                                continuation.yield((clock.now, el))
                            }
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
                
                while let (instant, element) = try await iterator.next() {
                    
                    if let firstIntervalInstant {
                        
                        // Set first element in interval
                        if firstElement == nil {
                            firstElement = element
                        }
                        
                        // Update last element in interval
                        lastElement = element
                        
                        let timeSinceFirstInstant = firstIntervalInstant.duration(to: clock.now)
                        
                        if timeSinceFirstInstant >= interval {
                            // Start new interval and reset first element
                            self.firstIntervalInstant = instant
                            firstElement = nil
                            return latest ? lastElement : firstElement
                        } else {
                            continue
                        }
                    } else {
                        // return first element in sequence and start throttle invervals
                        firstIntervalInstant = instant
                        return element
                    }
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
