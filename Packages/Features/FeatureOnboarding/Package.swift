// swift-tools-version: 6.0

// Mirrors Android module `:feature:onboarding`.

import PackageDescription

let package = Package(
    name: "FeatureOnboarding",
    // Turkish is the default AND the fallback locale (spec 6.4), matching Android's `values/`
    // being Turkish and `values-en/` the translation. Every catalog-owning package repeats it.
    defaultLocalization: "tr",
    // macOS 14 is inherited from SalusDesignSystem/SalusUI so `swift test` runs on
    // a macOS host; iOS 17 remains the ship target. See SalusUI/Package.swift.
    platforms: [.iOS(.v17), .macOS(.v14)],
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
            ],
            resources: [
                .process("Resources")
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
