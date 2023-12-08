//
//  DelaySequence.swift
//
//
//  Created by Tyler Thompson on 12/8/23.
//

import Foundation

extension AsyncSequences {
    public struct DelaySequence<Upstream: AsyncSequence>: AsyncSequence {
        public typealias Element = Upstream.Element
        let upstream: Upstream
        let interval: Measurement<UnitDuration>
        
        public struct AsyncIterator: AsyncIteratorProtocol {
            let upstream: Upstream
            let interval: Measurement<UnitDuration>
            var delayed = false
            lazy var iterator = upstream.makeAsyncIterator()
            
            public mutating func next() async throws -> Element? {
                if !delayed {
                    delayed = true
                    try await Task.sleep(nanoseconds: UInt64(interval.converted(to: .nanoseconds).value))
                }
                return try await iterator.next()
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
    public func delay(for interval: Measurement<UnitDuration>) -> AsyncSequences.DelaySequence<Self> {
        AsyncSequences.DelaySequence(upstream: self, interval: interval)
    }
}
