// swift-tools-version: 6.0

// Mirrors Android module `:feature:aihealth`.

import PackageDescription

let package = Package(
    name: "FeatureAIHealth",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FeatureAIHealth", targets: ["FeatureAIHealth"])
    ],
    dependencies: [
        .package(path: "../../SalusDesignSystem"),
        .package(path: "../../SalusUI"),
        .package(path: "../../SalusCommon"),
        .package(path: "../../SalusModel"),
        .package(path: "../../SalusAI"),
        .package(path: "../../SalusPremium"),
        .package(path: "../../SalusNavigation"),
        .package(path: "../../SalusSettings"),
        .package(path: "../../SalusTesting")
    ],
    targets: [
        .target(
            name: "FeatureAIHealth",
            dependencies: [
                .product(name: "SalusDesignSystem", package: "SalusDesignSystem"),
                .product(name: "SalusUI", package: "SalusUI"),
                .product(name: "SalusCommon", package: "SalusCommon"),
                .product(name: "SalusModel", package: "SalusModel"),
                .product(name: "SalusAI", package: "SalusAI"),
                .product(name: "SalusPremium", package: "SalusPremium"),
                .product(name: "SalusNavigation", package: "SalusNavigation"),
                .product(name: "SalusSettings", package: "SalusSettings")
            ]
        ),
        .testTarget(
            name: "FeatureAIHealthTests",
            dependencies: [
                "FeatureAIHealth",
                .product(name: "SalusTesting", package: "SalusTesting")
            ]
        )
    ]
)
