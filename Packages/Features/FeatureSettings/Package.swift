// swift-tools-version: 6.0

// Mirrors Android module `:feature:settings`.

import PackageDescription

let package = Package(
    name: "FeatureSettings",
    // Turkish is the default AND the fallback locale (spec 6.4), matching Android's `values/`
    // being Turkish and `values-en/` the translation. Every catalog-owning package repeats it.
    defaultLocalization: "tr",
    // macOS 14 is inherited from SalusDesignSystem/SalusUI so `swift test` runs on
    // a macOS host; iOS 17 remains the ship target. See SalusUI/Package.swift.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FeatureSettings", targets: ["FeatureSettings"])
    ],
    dependencies: [
        .package(path: "../../SalusDesignSystem"),
        .package(path: "../../SalusUI"),
        .package(path: "../../SalusCommon"),
        .package(path: "../../SalusModel"),
        .package(path: "../../SalusNavigation"),
        .package(path: "../../SalusReminder"),
        .package(path: "../../SalusSettings"),
        .package(path: "../../SalusProfile"),
        .package(path: "../../SalusPremium"),
        .package(path: "../../SalusTesting")
    ],
    targets: [
        .target(
            name: "FeatureSettings",
            dependencies: [
                .product(name: "SalusDesignSystem", package: "SalusDesignSystem"),
                .product(name: "SalusUI", package: "SalusUI"),
                .product(name: "SalusCommon", package: "SalusCommon"),
                .product(name: "SalusModel", package: "SalusModel"),
                .product(name: "SalusNavigation", package: "SalusNavigation"),
                .product(name: "SalusReminder", package: "SalusReminder"),
                .product(name: "SalusSettings", package: "SalusSettings"),
                .product(name: "SalusProfile", package: "SalusProfile"),
                .product(name: "SalusPremium", package: "SalusPremium")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "FeatureSettingsTests",
            dependencies: [
                "FeatureSettings",
                .product(name: "SalusTesting", package: "SalusTesting")
            ]
        )
    ]
)
