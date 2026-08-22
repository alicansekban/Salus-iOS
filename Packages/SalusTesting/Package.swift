// swift-tools-version: 6.0

// Mirrors Android module `:core:testing`.

import PackageDescription

let package = Package(
    name: "SalusTesting",
    // `.macOS(.v14)` is inherited, not chosen: SalusCommon declares it so that its `@Observable`
    // controller can be built for the test host, and the floor propagates to every dependent
    // (CLAUDE.md). iOS 17 remains the ship target.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SalusTesting", targets: ["SalusTesting"])
    ],
    dependencies: [
        .package(path: "../SalusCommon"),
        .package(path: "../SalusModel")
    ],
    targets: [
        .target(
            name: "SalusTesting",
            dependencies: [
                .product(name: "SalusCommon", package: "SalusCommon")
            ]
        ),
        .testTarget(
            name: "SalusTestingTests",
            dependencies: [
                "SalusTesting",
                // The fixed clock's expected days are `LocalDate`s. The library target itself
                // needs none of this — only the tests that pin what the clock reports do.
                .product(name: "SalusModel", package: "SalusModel")
            ]
        )
    ]
)
