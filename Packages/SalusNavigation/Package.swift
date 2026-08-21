// swift-tools-version: 6.0

// Mirrors Android module `:core:navigation`.

import PackageDescription

let package = Package(
    name: "SalusNavigation",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SalusNavigation", targets: ["SalusNavigation"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SalusNavigation",
            dependencies: []
        ),
        .testTarget(
            name: "SalusNavigationTests",
            dependencies: [
                "SalusNavigation"
            ]
        )
    ]
)
