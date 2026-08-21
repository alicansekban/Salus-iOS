// swift-tools-version: 6.0

// Mirrors Android module `:feature:trends`.

import PackageDescription

let package = Package(
    name: "FeatureTrends",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FeatureTrends", targets: ["FeatureTrends"])
    ],
    dependencies: [
        .package(path: "../../SalusDesignSystem"),
        .package(path: "../../SalusUI"),
        .package(path: "../../SalusCommon"),
        .package(path: "../../SalusModel"),
        .package(path: "../../SalusNavigation"),
        .package(path: "../../SalusPremium"),
        .package(path: "../../SalusDatabase"),
        .package(path: "../../SalusSettings"),
        .package(path: "../../SalusTesting")
    ],
    targets: [
        .target(
            name: "FeatureTrends",
            dependencies: [
                .product(name: "SalusDesignSystem", package: "SalusDesignSystem"),
                .product(name: "SalusUI", package: "SalusUI"),
                .product(name: "SalusCommon", package: "SalusCommon"),
                .product(name: "SalusModel", package: "SalusModel"),
                .product(name: "SalusNavigation", package: "SalusNavigation"),
                .product(name: "SalusPremium", package: "SalusPremium"),
                .product(name: "SalusDatabase", package: "SalusDatabase"),
                .product(name: "SalusSettings", package: "SalusSettings")
            ]
        ),
        .testTarget(
            name: "FeatureTrendsTests",
            dependencies: [
                "FeatureTrends",
                .product(name: "SalusTesting", package: "SalusTesting")
            ]
        )
    ]
)
