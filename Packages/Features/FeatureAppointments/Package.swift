// swift-tools-version: 6.0

// Mirrors Android module `:feature:appointments`.

import PackageDescription

let package = Package(
    name: "FeatureAppointments",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FeatureAppointments", targets: ["FeatureAppointments"])
    ],
    dependencies: [
        .package(path: "../../SalusDesignSystem"),
        .package(path: "../../SalusUI"),
        .package(path: "../../SalusCommon"),
        .package(path: "../../SalusModel"),
        .package(path: "../../SalusNavigation"),
        .package(path: "../../SalusDatabase"),
        .package(path: "../../SalusReminder"),
        .package(path: "../../SalusProfile"),
        .package(path: "../../SalusTesting")
    ],
    targets: [
        .target(
            name: "FeatureAppointments",
            dependencies: [
                .product(name: "SalusDesignSystem", package: "SalusDesignSystem"),
                .product(name: "SalusUI", package: "SalusUI"),
                .product(name: "SalusCommon", package: "SalusCommon"),
                .product(name: "SalusModel", package: "SalusModel"),
                .product(name: "SalusNavigation", package: "SalusNavigation"),
                .product(name: "SalusDatabase", package: "SalusDatabase"),
                .product(name: "SalusReminder", package: "SalusReminder"),
                .product(name: "SalusProfile", package: "SalusProfile")
            ]
        ),
        .testTarget(
            name: "FeatureAppointmentsTests",
            dependencies: [
                "FeatureAppointments",
                .product(name: "SalusTesting", package: "SalusTesting")
            ]
        )
    ]
)
