// swift-tools-version: 6.0

// Mirrors Android module `:core:datastore`.

import PackageDescription

let package = Package(
    name: "SalusSettings",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SalusSettings", targets: ["SalusSettings"])
    ],
    dependencies: [
        .package(path: "../SalusModel"),
        .package(path: "../SalusCommon")
    ],
    targets: [
        .target(
            name: "SalusSettings",
            dependencies: [
                .product(name: "SalusModel", package: "SalusModel"),
                .product(name: "SalusCommon", package: "SalusCommon")
            ]
        ),
        .testTarget(
            name: "SalusSettingsTests",
            dependencies: [
                "SalusSettings"
            ]
        )
    ]
)
