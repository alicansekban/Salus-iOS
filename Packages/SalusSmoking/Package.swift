// swift-tools-version: 6.0

// Mirrors Android module `:core:smoking`.

import PackageDescription

let package = Package(
    name: "SalusSmoking",
    // Inherited test-host concession: this package links `SalusDatabase`, which must declare
    // macOS 14 to satisfy GRDB's macOS 10.15 floor on the host build (a dependent that names no
    // macOS platform is read as macOS 10.13 and cannot link it). iOS 17 stays the ship target.
    // There is no UI framework here: the models and calculators are pure domain.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SalusSmoking", targets: ["SalusSmoking"])
    ],
    dependencies: [
        .package(path: "../SalusModel"),
        .package(path: "../SalusCommon"),
        .package(path: "../SalusDatabase"),
        .package(path: "../SalusPremium"),
        .package(path: "../SalusTesting")
    ],
    targets: [
        .target(
            name: "SalusSmoking",
            dependencies: [
                .product(name: "SalusModel", package: "SalusModel"),
                .product(name: "SalusCommon", package: "SalusCommon"),
                .product(name: "SalusDatabase", package: "SalusDatabase"),
                .product(name: "SalusPremium", package: "SalusPremium")
            ]
        ),
        .testTarget(
            name: "SalusSmokingTests",
            dependencies: [
                "SalusSmoking",
                // Test-target only: the library must never link the fixtures.
                .product(name: "SalusTesting", package: "SalusTesting")
            ],
            resources: [
                // The cross-platform golden vectors land here with the contract sync (plan
                // Task 22); the directory is tracked now so this declaration resolves.
                .copy("Resources")
            ]
        )
    ]
)
