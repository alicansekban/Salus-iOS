// swift-tools-version: 6.0

// Mirrors Android module `:core:premium`.

import PackageDescription

let package = Package(
    name: "SalusPremium",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SalusPremium", targets: ["SalusPremium"])
    ],
    dependencies: [
        .package(path: "../SalusModel")
    ],
    targets: [
        .target(
            name: "SalusPremium",
            dependencies: [
                .product(name: "SalusModel", package: "SalusModel")
            ]
        ),
        .testTarget(
            name: "SalusPremiumTests",
            dependencies: [
                "SalusPremium"
            ]
        )
    ]
)
