// swift-tools-version: 6.0

// Mirrors Android module `:feature:paywall`.

import PackageDescription

let package = Package(
    name: "FeaturePaywall",
    // Turkish is the default AND the fallback locale (spec 6.4), matching Android's values/.
    defaultLocalization: "tr",
    // macOS 14 is inherited from SalusDesignSystem/SalusUI so `swift test` runs on
    // a macOS host; iOS 17 remains the ship target. See SalusUI/Package.swift.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FeaturePaywall", targets: ["FeaturePaywall"])
    ],
    dependencies: [
        .package(path: "../../SalusDesignSystem"),
        .package(path: "../../SalusUI"),
        .package(path: "../../SalusCommon"),
        .package(path: "../../SalusModel"),
        .package(path: "../../SalusPremium"),
        .package(path: "../../SalusTesting")
    ],
    targets: [
        .target(
            name: "FeaturePaywall",
            dependencies: [
                .product(name: "SalusDesignSystem", package: "SalusDesignSystem"),
                .product(name: "SalusUI", package: "SalusUI"),
                .product(name: "SalusCommon", package: "SalusCommon"),
                .product(name: "SalusModel", package: "SalusModel"),
                .product(name: "SalusPremium", package: "SalusPremium")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "FeaturePaywallTests",
            dependencies: [
                "FeaturePaywall",
                .product(name: "SalusTesting", package: "SalusTesting")
            ]
        )
    ]
)
