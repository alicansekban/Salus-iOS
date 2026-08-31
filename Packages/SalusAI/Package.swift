// swift-tools-version: 6.0

// Mirrors Android module `:core:ai`.

import PackageDescription

let package = Package(
    name: "SalusAI",
    defaultLocalization: "tr",
    // Inherited test-host concession: this package links `SalusDatabase`, which must declare
    // macOS 14 to satisfy GRDB's macOS 10.15 floor on the host build. A dependent that names no
    // macOS platform is treated as macOS 10.13 and cannot link it. iOS 17 stays the ship target.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SalusAI", targets: ["SalusAI"])
    ],
    dependencies: [
        .package(path: "../SalusDatabase"),
        .package(path: "../SalusModel"),
        .package(path: "../SalusCommon"),
        .package(path: "../SalusPremium"),
        .package(path: "../SalusSettings"),
        .package(path: "../SalusTesting")
    ],
    targets: [
        .target(
            name: "SalusAI",
            dependencies: [
                .product(name: "SalusDatabase", package: "SalusDatabase"),
                .product(name: "SalusModel", package: "SalusModel"),
                .product(name: "SalusCommon", package: "SalusCommon"),
                .product(name: "SalusPremium", package: "SalusPremium"),
                .product(name: "SalusSettings", package: "SalusSettings")
            ]
        ),
        .testTarget(
            name: "SalusAITests",
            dependencies: [
                "SalusAI",
                .product(name: "SalusTesting", package: "SalusTesting")
            ]
        )
    ]
)
