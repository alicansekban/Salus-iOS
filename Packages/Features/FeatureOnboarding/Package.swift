// swift-tools-version: 6.0

// Mirrors Android module `:feature:onboarding`.

import PackageDescription

let package = Package(
    name: "FeatureOnboarding",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FeatureOnboarding", targets: ["FeatureOnboarding"])
    ],
    dependencies: [
        .package(path: "../../SalusDesignSystem"),
        .package(path: "../../SalusUI"),
        .package(path: "../../SalusCommon"),
        .package(path: "../../SalusModel"),
        .package(path: "../../SalusProfile"),
        .package(path: "../../SalusDatabase"),
        .package(path: "../../SalusSettings"),
        .package(path: "../../SalusTesting")
    ],
    targets: [
        .target(
            name: "FeatureOnboarding",
            dependencies: [
                .product(name: "SalusDesignSystem", package: "SalusDesignSystem"),
                .product(name: "SalusUI", package: "SalusUI"),
                .product(name: "SalusCommon", package: "SalusCommon"),
                .product(name: "SalusModel", package: "SalusModel"),
                .product(name: "SalusProfile", package: "SalusProfile"),
                .product(name: "SalusDatabase", package: "SalusDatabase"),
                .product(name: "SalusSettings", package: "SalusSettings")
            ]
        ),
        .testTarget(
            name: "FeatureOnboardingTests",
            dependencies: [
                "FeatureOnboarding",
                .product(name: "SalusTesting", package: "SalusTesting")
            ]
        )
    ]
)
