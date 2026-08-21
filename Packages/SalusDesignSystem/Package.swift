// swift-tools-version: 6.0

// Mirrors Android module `:core:designsystem`.

import PackageDescription

let package = Package(
    name: "SalusDesignSystem",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SalusDesignSystem", targets: ["SalusDesignSystem"])
    ],
    dependencies: [
        .package(path: "../SalusModel")
    ],
    targets: [
        .target(
            name: "SalusDesignSystem",
            dependencies: [
                .product(name: "SalusModel", package: "SalusModel")
            ]
        ),
        .testTarget(
            name: "SalusDesignSystemTests",
            dependencies: [
                "SalusDesignSystem"
            ]
        )
    ]
)
