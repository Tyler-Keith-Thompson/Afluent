// Adapted from Tyler Thompson's SeededRandomNumberGenerator
// (https://github.com/Tyler-Keith-Thompson/RandomSideProjects/tree/main/SeededRandomNumberGenerator,
// MIT License, Copyright (c) 2021 Tyler Thompson).
//
// Changes from the original:
// - Seeding follows the SplitMix64 reference (https://prng.di.unimi.it/splitmix64.c) and fills
//   both state words.
// - `next() -> UInt64` implements the protocol requirement.
// - The project's global `RNG` and `%%` operator are not included.

// translated from: http://xoroshiro.di.unimi.it/xoroshiro128plus.c

/// xoroshiro128+ (the 2016 version, rotations 55, 14 and 36), seeded with SplitMix64.
///
/// Deterministic for a given seed on every platform, so a randomized test case can be reproduced
/// from its seed alone.
public struct SeededRandomNumberGenerator: RandomNumberGenerator, Sendable {
    private var state: (UInt64, UInt64)

    public init(seed: UInt = .random(in: .min ... .max)) {
        var splitMix = UInt64(seed)
        func nextSplitMix() -> UInt64 {
            splitMix &+= 0x9E37_79B9_7F4A_7C15
            var z = splitMix
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
        state = (nextSplitMix(), nextSplitMix())
    }

    public mutating func next() -> UInt64 {
        let (s0, s1) = state
        let result = s0 &+ s1
        let mixed = s1 ^ s0
        state = (rotateLeft(s0, by: 55) ^ mixed ^ (mixed << 14), rotateLeft(mixed, by: 36))
        return result
    }

    private func rotateLeft(_ value: UInt64, by amount: UInt64) -> UInt64 {
        (value << amount) | (value >> (64 - amount))
    }
}
