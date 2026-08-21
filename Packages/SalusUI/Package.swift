// swift-tools-version: 6.0

// Mirrors Android module `:core:ui`.

import PackageDescription

let package = Package(
    name: "SalusUI",
    platforms: [.iOS(.v17)],
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
