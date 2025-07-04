//
//  ThrottleSequence.swift
//
//
//  Created by Trip Phillips on 2/12/24.
//

import Foundation

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
extension AsyncSequences {
    public struct Throttle<Upstream: AsyncSequence & Sendable, C: Clock>: AsyncSequence, Sendable
    where Upstream.Element: Sendable {
        public typealias Element = Upstream.Element
        let upstream: Upstream
        let interval: C.Duration
        let clock: C
        let latest: Bool

        public struct AsyncIterator: AsyncIteratorProtocol {
            init(upstream: Upstream, interval: C.Duration, clock: C, latest: Bool) {
                self.upstream = upstream
                self.interval = interval
                self.clock = clock
                self.latest = latest
                self.state = State()
            }

            private let upstream: Upstream
            private let interval: C.Duration
            private let clock: C
            private let latest: Bool
            private let state: State
            private var iterationTask: Task<Void, Never>?

            public mutating func next() async throws -> Element? {
                try Task.checkCancellation()

                if await state.finished {
                    return nil
                }

                return try await nextUpstreamElement()
            }

            private mutating func nextUpstreamElement() async throws -> Element? {
                await startIterationIfNecessary()
                try await waitForNextInterval()

                await Task.yield()
                try Task.checkCancellation()

                let clock = self.clock
                let nextElement = await state.consumeNextElement(at: { clock.now })
                switch nextElement {
                    case .emitted(let element):
                        return element
                    case .error(let error):
                        cancelTask()
                        throw error
                    case .finished:
                        cancelTask()
                        return nil
                }
            }

            private mutating func cancelTask() {
                self.iterationTask?.cancel()
            }

            private mutating func startIterationIfNecessary() async {
                guard iterationTask == nil else { return }

                let upstream = self.upstream
                let latest = self.latest
                let state = self.state

                self.iterationTask = Task {
                    do {
                        for try await element in upstream {
                            async let _ = state.setNext(element: element, useLatest: latest)
                        }
                        await state.setFinish()
                    } catch {
                        await state.setError(error)
                    }
                }
                await Task.yield()
            }

            private func waitForNextInterval() async throws {
                guard let lastElementEmittedInstant = await state.lastElementEmittedInstant else {
                    return
                }
                let nextInstant = lastElementEmittedInstant.advanced(by: interval)
                try await clock.sleep(until: nextInstant, tolerance: nil)
                await Task.yield()
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(
                upstream: upstream,
                interval: interval,
                clock: clock,
                latest: latest)
        }
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
extension AsyncSequences.Throttle.AsyncIterator {
    /// An event from the upstream sequence.
    private enum ElementEvent {
        case emitted(Element)
        case error(Error)
        case finished

        /// Returns `true` if either `finished` or `error`.
        var isFinished: Bool {
            switch self {
                case .emitted: return false
                case .error: return true
                case .finished: return true
            }
        }
    }

    private actor State: Sendable {
        /// Sets the next element as "finished", overwriting any currently set element.
        func setFinish() {
            if self._nextElement.alreadySent {
                self._nextElement = .init()
            }
            try! self._nextElement.send(.finished)
        }

        /// When an error occurs, sets the next element as an error, overwriting any currently set element.
        func setError(_ error: Error) {
            if self._nextElement.alreadySent {
                self._nextElement = .init()
            }
            try! self._nextElement.send(.error(error))
        }

        /// Sets the next element.
        /// If using latest, this element will be set for staging.
        /// If _not_ using latest, the element will be set if no other element is already set.
        func setNext(element: Element, useLatest: Bool) {
            let alreadySent = self._nextElement.alreadySent
            if useLatest || alreadySent == false {
                if alreadySent {
                    self._nextElement = .init()
                }
                try! self._nextElement.send(.emitted(element))
            }
        }

        /// Waits to consume the element that's next.
        /// Will continue to wait indefinitely on the upstream to emit an event until either an element, error, or finish is received.
        /// Calling this function also sets the `lastElementEmittedInstant` at the time the next element is received, using the passed `instant` function.
        func consumeNextElement(at instant: @escaping @Sendable () -> C.Instant) async
            -> ElementEvent
        {
            let element: ElementEvent
            do {
                element = try await self._nextElement.execute()
            } catch {
                element = .error(error)
            }

            self._nextElement = .init()
            self._lastElementEmittedInstant = instant()
            self._finished = element.isFinished
            return element
        }

        /// The last instant an element was emitted, if an element has already been emitted.
        /// This value is `nil` if no element has been emitted yet.
        var lastElementEmittedInstant: C.Instant? {
            _lastElementEmittedInstant
        }

        /// Indicates whether the upstream has finished with `nil` or an error.
        var finished: Bool {
            _finished
        }

        // using a SingleValueSubject means that we need to re-init the subject every time we want to send a new value
        // this _seems_ like it may introduce a race condition, but it does not
        // this is because the _nextElement subject will just await whatever has been sent or will be sent
        // even if the actor's _nextValue property happens to be set while a previously-set _nextValue is still awaiting
        private var _nextElement = SingleValueSubject<ElementEvent>()
        private var _lastElementEmittedInstant: C.Instant?
        private var _finished = false
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
extension AsyncSequence where Self: Sendable, Element: Sendable {
    /// Allows only one element to pass through during each specified interval, emitting either the first or the latest element seen in that period.
    ///
    /// This operator suppresses elements from the upstream async sequence during each interval, emitting only one element per interval:
    /// - If `latest` is `false`, it emits the first element received immediately and then ignores subsequent elements until the interval completes.
    /// - If `latest` is `true`, it emits the first element immediately, then during the interval it tracks element updates, emitting only the most recent one at the interval’s end.
    ///
    /// Elements arriving during an interval beyond the emitted one are suppressed, allowing controlled pacing of element emission.
    ///
    /// - Parameters:
    ///   - interval: The length of time to wait between emissions.
    ///   - clock: The clock used to measure time intervals and perform sleeps.
    ///   - latest: A Boolean flag determining which element to emit during each interval:
    ///     - `false` emits the first element seen in the interval.
    ///     - `true` emits the latest element seen during the interval.
    ///
    /// - Returns: An async sequence that emits throttled elements from the upstream sequence.
    ///
    /// ## Example
    ///
    /// The following example creates an `AsyncStream` that emits the current date every second,
    /// then applies a throttle with a 3-second interval, showing both `latest: false` and `latest: true`.
    ///
    /// ```swift
    /// import Foundation
    /// import _Concurrency
    ///
    /// let stream = AsyncStream<Date> { continuation in
    ///     Task {
    ///         while true {
    ///             continuation.yield(Date())
    ///             try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    ///         }
    ///     }
    /// }
    ///
    /// // Throttle with latest: false (emit the first element immediately, then suppress others during the interval)
    /// Task {
    ///     print("Throttle with latest: false")
    ///     for await date in stream.throttle(for: .seconds(3), clock: ContinuousClock(), latest: false) {
    ///         print("Emitted (first): \(date)")
    ///     }
    /// }
    ///
    /// // Throttle with latest: true (emit the first element immediately, then emit the latest element at interval end)
    /// Task {
    ///     print("Throttle with latest: true")
    ///     for await date in stream.throttle(for: .seconds(3), clock: ContinuousClock(), latest: true) {
    ///         print("Emitted (latest): \(date)")
    ///     }
    /// }
    ///
    /// /*
    /// Sample output for latest: false:
    /// Throttle with latest: false
    /// Emitted (first): 2025-07-04 12:00:00 +0000
    /// Emitted (first): 2025-07-04 12:00:03 +0000
    /// Emitted (first): 2025-07-04 12:00:06 +0000
    ///
    /// Sample output for latest: true:
    /// Throttle with latest: true
    /// Emitted (latest): 2025-07-04 12:00:00 +0000
    /// Emitted (latest): 2025-07-04 12:00:02 +0000
    /// Emitted (latest): 2025-07-04 12:00:05 +0000
    /// */
    /// ```
    public func throttle<C: Clock>(for interval: C.Duration, clock: C, latest: Bool)
        -> AsyncSequences.Throttle<Self, C>
    {
        AsyncSequences.Throttle(upstream: self, interval: interval, clock: clock, latest: latest)
    }
}
