// swift-tools-version: 6.0

// Mirrors Android module `:feature:vitals`.

import PackageDescription

let package = Package(
    name: "FeatureVitals",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FeatureVitals", targets: ["FeatureVitals"])
    ],
    dependencies: [
        .package(path: "../../SalusDesignSystem"),
        .package(path: "../../SalusUI"),
        .package(path: "../../SalusCommon"),
        .package(path: "../../SalusModel"),
        .package(path: "../../SalusNavigation"),
        .package(path: "../../SalusDatabase"),
        .package(path: "../../SalusSettings"),
        .package(path: "../../SalusTesting")
    ],
    targets: [
        .target(
            name: "FeatureVitals",
            dependencies: [
                .product(name: "SalusDesignSystem", package: "SalusDesignSystem"),
                .product(name: "SalusUI", package: "SalusUI"),
                .product(name: "SalusCommon", package: "SalusCommon"),
                .product(name: "SalusModel", package: "SalusModel"),
                .product(name: "SalusNavigation", package: "SalusNavigation"),
                .product(name: "SalusDatabase", package: "SalusDatabase"),
                .product(name: "SalusSettings", package: "SalusSettings")
            ]
        ),
        .testTarget(
            name: "FeatureVitalsTests",
            dependencies: [
                "FeatureVitals",
                .product(name: "SalusTesting", package: "SalusTesting")
            ]
        )
    ]
)
