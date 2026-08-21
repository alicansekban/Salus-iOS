// swift-tools-version: 6.0

// Mirrors Android module `:core:testing`.

import PackageDescription

let package = Package(
    name: "SalusTesting",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SalusTesting", targets: ["SalusTesting"])
    ],
    dependencies: [
        .package(path: "../SalusCommon")
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
                "SalusTesting"
            ]
        )
    ]
)
