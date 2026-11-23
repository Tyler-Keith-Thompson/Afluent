//
//  FIFOQueue.swift
//  Afluent
//

/// A first-in, first-out queue over an array: values are appended at the back and taken from the front.
///
/// The subjects and `share()` buffer each consumer's unread values in one, inside their lock, so taking a value must
/// not shift the rest: `Array.removeFirst()` would make draining a backlog of n values O(n²) while every sender waits.
struct FIFOQueue<Element> {
    // swift-collections' `Deque` does this, but `Afluent` takes no runtime dependency; a head index into an array
    // that drops its taken prefix once it is half the storage keeps both operations amortized O(1).

    /// The queued values, from `head` on; the slots before `head` were taken and hold `nil`, so a taken value is
    /// released at once rather than when the prefix is dropped.
    private var storage = [Element?]()
    private var head = 0

    init() {}

    /// Adds a value at the back.
    ///
    /// - Complexity: Amortized O(1).
    mutating func append(_ element: Element) {
        storage.append(element)
    }

    /// Removes and returns the value at the front, or `nil` when the queue is empty.
    ///
    /// - Complexity: Amortized O(1): the taken prefix is dropped once it is half the storage, which moves at most as
    ///   many values as were taken since the last drop.
    mutating func popFirst() -> Element? {
        guard head < storage.count else { return nil }
        let element = storage[head].take()
        head += 1
        if head == storage.count {
            storage.removeAll(keepingCapacity: true)
            head = 0
        } else if head * 2 >= storage.count {
            storage.removeFirst(head)
            head = 0
        }
        return element
    }

    /// Removes every value.
    mutating func removeAll() {
        storage.removeAll()
        head = 0
    }
}

extension FIFOQueue: Sendable where Element: Sendable {}
