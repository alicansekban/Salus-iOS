// swift-tools-version: 6.0

// Mirrors Android module `:feature:medications`.

import PackageDescription

let package = Package(
    name: "FeatureMedications",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FeatureMedications", targets: ["FeatureMedications"])
    ],
    dependencies: [
        .package(path: "../../SalusDesignSystem"),
        .package(path: "../../SalusUI"),
        .package(path: "../../SalusCommon"),
        .package(path: "../../SalusModel"),
        .package(path: "../../SalusNavigation"),
        .package(path: "../../SalusDatabase"),
        .package(path: "../../SalusReminder"),
        .package(path: "../../SalusTesting")
    ],
    targets: [
        .target(
            name: "FeatureMedications",
            dependencies: [
                .product(name: "SalusDesignSystem", package: "SalusDesignSystem"),
                .product(name: "SalusUI", package: "SalusUI"),
                .product(name: "SalusCommon", package: "SalusCommon"),
                .product(name: "SalusModel", package: "SalusModel"),
                .product(name: "SalusNavigation", package: "SalusNavigation"),
                .product(name: "SalusDatabase", package: "SalusDatabase"),
                .product(name: "SalusReminder", package: "SalusReminder")
            ]
        ),
        .testTarget(
            name: "FeatureMedicationsTests",
            dependencies: [
                "FeatureMedications",
                .product(name: "SalusTesting", package: "SalusTesting")
            ]
        )
    ]
)
