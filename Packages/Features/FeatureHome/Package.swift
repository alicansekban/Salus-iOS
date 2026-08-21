// swift-tools-version: 6.0

// Mirrors Android module `:feature:home`.

import PackageDescription

let package = Package(
    name: "FeatureHome",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FeatureHome", targets: ["FeatureHome"])
    ],
    dependencies: [
        .package(path: "../../SalusDesignSystem"),
        .package(path: "../../SalusUI"),
        .package(path: "../../SalusCommon"),
        .package(path: "../../SalusModel"),
        .package(path: "../../SalusNavigation"),
        .package(path: "../../SalusDatabase"),
        .package(path: "../../SalusSettings"),
        .package(path: "../../SalusAI"),
        .package(path: "../../SalusPremium"),
        .package(path: "../../SalusTesting")
    ],
    targets: [
        .target(
            name: "FeatureHome",
            dependencies: [
                .product(name: "SalusDesignSystem", package: "SalusDesignSystem"),
                .product(name: "SalusUI", package: "SalusUI"),
                .product(name: "SalusCommon", package: "SalusCommon"),
                .product(name: "SalusModel", package: "SalusModel"),
                .product(name: "SalusNavigation", package: "SalusNavigation"),
                .product(name: "SalusDatabase", package: "SalusDatabase"),
                .product(name: "SalusSettings", package: "SalusSettings"),
                .product(name: "SalusAI", package: "SalusAI"),
                .product(name: "SalusPremium", package: "SalusPremium")
            ]
        ),
        .testTarget(
            name: "FeatureHomeTests",
            dependencies: [
                "FeatureHome",
                .product(name: "SalusTesting", package: "SalusTesting")
            ]
        )
    ]
)
