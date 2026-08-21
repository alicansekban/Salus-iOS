// swift-tools-version: 6.0

// Mirrors Android module `:feature:cycle`.

import PackageDescription

let package = Package(
    name: "FeatureCycle",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FeatureCycle", targets: ["FeatureCycle"])
    ],
    dependencies: [
        .package(path: "../../SalusDesignSystem"),
        .package(path: "../../SalusUI"),
        .package(path: "../../SalusCommon"),
        .package(path: "../../SalusModel"),
        .package(path: "../../SalusNavigation"),
        .package(path: "../../SalusDatabase"),
        .package(path: "../../SalusSettings"),
        .package(path: "../../SalusReminder"),
        .package(path: "../../SalusTesting")
    ],
    targets: [
        .target(
            name: "FeatureCycle",
            dependencies: [
                .product(name: "SalusDesignSystem", package: "SalusDesignSystem"),
                .product(name: "SalusUI", package: "SalusUI"),
                .product(name: "SalusCommon", package: "SalusCommon"),
                .product(name: "SalusModel", package: "SalusModel"),
                .product(name: "SalusNavigation", package: "SalusNavigation"),
                .product(name: "SalusDatabase", package: "SalusDatabase"),
                .product(name: "SalusSettings", package: "SalusSettings"),
                .product(name: "SalusReminder", package: "SalusReminder")
            ]
        ),
        .testTarget(
            name: "FeatureCycleTests",
            dependencies: [
                "FeatureCycle",
                .product(name: "SalusTesting", package: "SalusTesting")
            ]
        )
    ]
)
