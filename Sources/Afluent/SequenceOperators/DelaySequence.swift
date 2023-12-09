//
//  DelaySequence.swift
//
//
//  Created by Tyler Thompson on 12/8/23.
//

import Foundation

extension AsyncSequences {
    public struct Delay<Upstream: AsyncSequence>: AsyncSequence {
        public typealias Element = Upstream.Element
        let upstream: Upstream
        let interval: Measurement<UnitDuration>
        
        public struct AsyncIterator: AsyncIteratorProtocol {
            typealias Instant = SuspendingClock.Instant
            let upstream: Upstream
            let interval: Measurement<UnitDuration>
            var iterator: AsyncThrowingStream<(Instant, Element), Error>.Iterator
            let clock: SuspendingClock

            init(upstream: Upstream, interval: Measurement<UnitDuration>) {
                self.upstream = upstream
                self.interval = interval
                let (stream, continuation) = AsyncThrowingStream<(Instant, Element), Error>.makeStream()
                self.iterator = stream.makeAsyncIterator()
                let clock = SuspendingClock()
                self.clock = clock
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
            
            public mutating func next() async throws -> Element? {
                try Task.checkCancellation()
                if let (instant, element) = try await iterator.next() {
                    let suspensionPoint = instant.advanced(by: .nanoseconds(UInt(interval.converted(to: .nanoseconds).value)))
                    try await clock.sleep(until: suspensionPoint)
                    return element
                }
                return nil
            }
        }
        
        
        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(upstream: upstream, interval: interval)
        }
    }
}

extension AsyncSequence {
    /// Delays delivery of all output to the downstream receiver by a specified amount of time
    /// - Parameter interval: The amount of time to delay.
    public func delay(for interval: Measurement<UnitDuration>) -> AsyncSequences.Delay<Self> {
        AsyncSequences.Delay(upstream: self, interval: interval)
    }
}
