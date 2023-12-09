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
            let upstream: Upstream
            let interval: Measurement<UnitDuration>
            let stream: AsyncThrowingStream<Element, Error>
            let continuation: AsyncThrowingStream<Element, Error>.Continuation
            lazy var iterator = stream.makeAsyncIterator()

            init(upstream: Upstream, interval: Measurement<UnitDuration>) {
                self.upstream = upstream
                self.interval = interval
                let (stream, continuation) = AsyncThrowingStream<Element, Error>.makeStream()
                self.stream = stream
                self.continuation = continuation
                Task {
                    do {
                        var task: (any AsynchronousUnitOfWork<Void>)?
                        for try await el in upstream {
                            let t = DeferredTask { el }
                                .delay(for: interval)
                                .map { continuation.yield($0) }
                                .share()
                            t.run()
                            task = t.discardOutput()
                        }
                        DeferredTask { [task] in try await task?.result.get() }
                            .map { continuation.finish() }
                            .run()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }
            
            public mutating func next() async throws -> Element? {
                try Task.checkCancellation()
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
    public func delay(for interval: Measurement<UnitDuration>) -> AsyncSequences.Delay<Self> {
        AsyncSequences.Delay(upstream: self, interval: interval)
    }
}
