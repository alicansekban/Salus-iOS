// swift-tools-version: 6.0

// Mirrors Android module `:core:ui`.

import PackageDescription

let package = Package(
    name: "SalusUI",
    // Project convention: iOS is the ship target, and a package that (directly or
    // transitively) reaches SwiftUI also declares macOS 14 solely so `swift test`
    // can build and run its tests on a macOS host. Here it is inherited: the
    // dependency on SalusDesignSystem, which draws SwiftUI values, requires
    // macOS 14, and SwiftPM refuses to resolve a lower host floor above it.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SalusUI", targets: ["SalusUI"])
    ],
    dependencies: [
        .package(path: "../SalusDesignSystem"),
        .package(path: "../SalusCommon"),
        .package(path: "../SalusModel")
    ],
    targets: [
        .target(
            name: "SalusUI",
            dependencies: [
                .product(name: "SalusDesignSystem", package: "SalusDesignSystem"),
                .product(name: "SalusCommon", package: "SalusCommon"),
                .product(name: "SalusModel", package: "SalusModel")
            ]
        ),
        .testTarget(
            name: "SalusUITests",
            dependencies: [
                "SalusUI"
            ]
        )
    ]
)
