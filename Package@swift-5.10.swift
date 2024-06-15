// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(name: "Afluent",
                      platforms: [.iOS(.v15), .macOS(.v13), .macCatalyst(.v15), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1)],
                      products: [
                          .library(name: "Afluent",
                                   targets: ["Afluent"]),
                      ],
                      dependencies: [
                          .package(url: "https://github.com/apple/swift-atomics.git", from: "1.2.0"),
                          .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
                          .package(url: "https://github.com/AliSoftware/OHHTTPStubs.git", from: "9.1.0"),
                          .package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.52.11"),
                          .package(url: "https://github.com/pointfreeco/swift-clocks.git", from: "1.0.2"),
                          .package(url: "https://github.com/pointfreeco/swift-concurrency-extras.git", from: "1.1.0"),
                          .package(url: "https://github.com/apple/swift-testing.git", from: "0.7.0"),
                      ],
                      targets: [
                          .target(name: "Afluent",
                                  dependencies: [
                                      .product(name: "Atomics", package: "swift-atomics"),
                                  ],
                                  swiftSettings: [
                                      .enableExperimentalFeature("StrictConcurrency=complete"),
                                  ]),
                          .testTarget(name: "AfluentTests",
                                      dependencies: testDependencies()),
                      ])

func testDependencies() -> [PackageDescription.Target.Dependency] {
    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        [
            "Afluent",
            .product(name: "OHHTTPStubs", package: "OHHTTPStubs"),
            .product(name: "OHHTTPStubsSwift", package: "OHHTTPStubs"),
            .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
            .product(name: "Clocks", package: "swift-clocks"),
            .product(name: "Testing", package: "swift-testing"),
        ]
    #else
        [
            "Afluent",
            .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
            .product(name: "Clocks", package: "swift-clocks"),
            .product(name: "Testing", package: "swift-testing"),
        ]
    #endif
}
