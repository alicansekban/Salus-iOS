// swift-tools-version: 6.0

// Mirrors Android module `:core:profile`.

import PackageDescription

let package = Package(
    name: "SalusProfile",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SalusProfile", targets: ["SalusProfile"])
    ],
    dependencies: [
        .package(path: "../SalusModel"),
        .package(path: "../SalusCommon"),
        .package(path: "../SalusDatabase")
    ],
    targets: [
        .target(
            name: "SalusProfile",
            dependencies: [
                .product(name: "SalusModel", package: "SalusModel"),
                .product(name: "SalusCommon", package: "SalusCommon"),
                .product(name: "SalusDatabase", package: "SalusDatabase")
            ]
        ),
        .testTarget(
            name: "SalusProfileTests",
            dependencies: [
                "SalusProfile"
            ]
        )
    ]
)
