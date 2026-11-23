//
//  FIFOQueueTests.swift
//  Afluent
//

import PropertyBased
import Testing

@testable import Afluent

struct FIFOQueueTests {
    @Test("An empty queue pops nil")
    func emptyQueuePopsNil() {
        var sut = FIFOQueue<Int>()

        let actual = sut.popFirst()

        #expect(actual == nil)
    }

    @Test("A queue of one value pops it, then nil")
    func oneValue() {
        var sut = FIFOQueue<Int>()
        sut.append(7)
        let expected: [Int?] = [7, nil]

        let actual = [sut.popFirst(), sut.popFirst()]

        #expect(actual == expected)
    }

    @Test("Values pop in the order they were appended, across the point where the taken prefix is dropped")
    func popsInAppendOrder() {
        var sut = FIFOQueue<Int>()
        for value in 1...4 { sut.append(value) }
        let expected: [Int?] = [1, 2, 3, 4, 5, 6, nil]

        var actual = [sut.popFirst(), sut.popFirst()]
        sut.append(5)
        actual.append(sut.popFirst())
        sut.append(6)
        for _ in 0..<4 { actual.append(sut.popFirst()) }

        #expect(actual == expected)
    }

    @Test("removeAll empties the queue, and it takes values again afterwards")
    func removeAllEmpties() {
        var sut = FIFOQueue<Int>()
        for value in 1...3 { sut.append(value) }
        _ = sut.popFirst()
        let expected: [Int?] = [nil, 9, nil]

        sut.removeAll()
        var actual = [sut.popFirst()]
        sut.append(9)
        actual += [sut.popFirst(), sut.popFirst()]

        #expect(actual == expected)
    }

    @Test("A popped value is released at once, not when the taken prefix is dropped")
    func poppedValueIsReleased() {
        final class Box {}
        var sut = FIFOQueue<Box>()
        weak var first: Box?
        do {
            let box = Box()
            first = box
            sut.append(box)
        }
        for _ in 0..<3 { sut.append(Box()) }

        _ = sut.popFirst()

        #expect(first == nil)
    }

    @Test("Any run of appends and pops gives what an array with removeFirst gives")
    func matchesArrayReference() async {
        // A negative operation pops; any other appends that value.
        await propertyCheck(count: 500, input: Gen.int(in: -40...100).array(of: 0...256)) { operations in
            var sut = FIFOQueue<Int>()
            var reference = [Int]()
            var expected = [Int?]()
            var actual = [Int?]()

            for operation in operations {
                if operation < 0 {
                    expected.append(reference.isEmpty ? nil : reference.removeFirst())
                    actual.append(sut.popFirst())
                } else {
                    reference.append(operation)
                    sut.append(operation)
                }
            }
            while let value = sut.popFirst() { actual.append(value) }
            expected += reference.map { Optional($0) }

            #expect(actual == expected)
        }
    }
}
