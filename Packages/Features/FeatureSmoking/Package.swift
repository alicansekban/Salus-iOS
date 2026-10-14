// swift-tools-version: 6.0

// Mirrors Android module `:feature:smoking`.

import PackageDescription

let package = Package(
    name: "FeatureSmoking",
    // Turkish is the default AND the fallback locale (spec 6.4), matching Android's `values/`
    // being Turkish and `values-en/` the translation. Every catalog-owning package repeats it.
    defaultLocalization: "tr",
    // macOS 14 is inherited from SalusDesignSystem/SalusUI (and from SalusSmoking, which links
    // GRDB) so `swift test` runs on a macOS host; iOS 17 remains the ship target.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FeatureSmoking", targets: ["FeatureSmoking"])
    ],
    dependencies: [
        .package(path: "../../SalusDatabase"),
        .package(path: "../../SalusDesignSystem"),
        .package(path: "../../SalusUI"),
        .package(path: "../../SalusCommon"),
        .package(path: "../../SalusModel"),
        .package(path: "../../SalusNavigation"),
        .package(path: "../../SalusReminder"),
        .package(path: "../../SalusSmoking"),
        .package(path: "../../SalusTesting")
    ],
    targets: [
        .target(
            name: "FeatureSmoking",
            dependencies: [
                .product(name: "SalusDesignSystem", package: "SalusDesignSystem"),
                .product(name: "SalusUI", package: "SalusUI"),
                .product(name: "SalusCommon", package: "SalusCommon"),
                .product(name: "SalusModel", package: "SalusModel"),
                .product(name: "SalusNavigation", package: "SalusNavigation"),
                .product(name: "SalusReminder", package: "SalusReminder"),
                .product(name: "SalusSmoking", package: "SalusSmoking")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "FeatureSmokingTests",
            dependencies: [
                "FeatureSmoking",
                // The milestone-budget test runs the real reminder window over an in-memory ledger.
                .product(name: "SalusDatabase", package: "SalusDatabase"),
                .product(name: "SalusTesting", package: "SalusTesting")
            ]
        )
    ]
)
