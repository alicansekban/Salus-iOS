// swift-tools-version: 6.0

// Mirrors Android module `:core:datastore`.

import PackageDescription

let package = Package(
    name: "SalusSettings",
    // `.macOS(.v14)` is inherited, not chosen: SalusCommon declares it so that its `@Observable`
    // controller can be built for the test host, and the floor propagates to every dependent
    // (CLAUDE.md). iOS 17 remains the ship target.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SalusSettings", targets: ["SalusSettings"])
    ],
    dependencies: [
        .package(path: "../SalusModel"),
        .package(path: "../SalusCommon")
    ],
    targets: [
        .target(
            name: "SalusSettings",
            dependencies: [
                .product(name: "SalusModel", package: "SalusModel"),
                .product(name: "SalusCommon", package: "SalusCommon")
            ]
        ),
        .testTarget(
            name: "SalusSettingsTests",
            dependencies: [
                "SalusSettings"
            ]
        )
    ]
)
