// swift-tools-version: 5.10
// The package for toolchains older than Swift 6.3, which can't read Package.swift (generated
// by scripts/modules.py). SwiftPM picks the newest Package@swift-X.swift no newer than the
// toolchain. Kept by hand: a module, dependency or platform added to the table goes here too.

import PackageDescription

let package = Package(
    name: "Afluent",
    platforms: [
        .iOS(.v15), .macOS(.v13), .macCatalyst(.v15), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1),
    ],
    products: [
        .library(
            name: "Afluent",
            targets: ["Afluent"]),
        .library(
            name: "AfluentTesting",
            targets: ["AfluentTesting"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-atomics.git", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
        .package(url: "https://github.com/AliSoftware/OHHTTPStubs.git", from: "9.1.0"),
        .package(url: "https://github.com/pointfreeco/swift-clocks.git", from: "1.0.2"),
        .package(url: "https://github.com/pointfreeco/swift-concurrency-extras.git", from: "1.1.0"),
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.7.0"),
    ],
    targets: [
        .target(
            name: "Afluent",
            dependencies: [
                .product(name: "Atomics", package: "swift-atomics")
            ],
            exclude: ["BUILD.bazel"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency=complete")
            ]),
        .target(
            name: "AfluentTesting",
            dependencies: [
                "Afluent"
            ],
            exclude: ["BUILD.bazel"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency=complete")
            ]),
        .testTarget(
            name: "AfluentTests",
            dependencies: testDependencies(),
            exclude: ["BUILD.bazel"]),
    ])

func testDependencies() -> [PackageDescription.Target.Dependency] {
    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        [
            "Afluent",
            "AfluentTesting",
            .product(name: "OHHTTPStubs", package: "OHHTTPStubs"),
            .product(name: "OHHTTPStubsSwift", package: "OHHTTPStubs"),
            .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
            .product(name: "Clocks", package: "swift-clocks"),
            .product(name: "Testing", package: "swift-testing"),
        ]
    #else
        [
            "Afluent",
            "AfluentTesting",
            .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
            .product(name: "Clocks", package: "swift-clocks"),
            .product(name: "Testing", package: "swift-testing"),
        ]
    #endif
}
