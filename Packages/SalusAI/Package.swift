// swift-tools-version: 6.0

// Mirrors Android module `:core:ai`.

import PackageDescription

let package = Package(
    name: "SalusAI",
    platforms: [.iOS(.v17)],
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
