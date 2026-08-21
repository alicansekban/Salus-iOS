// swift-tools-version: 6.0

// Mirrors Android module `:core:notifications`.

import PackageDescription

let package = Package(
    name: "SalusNotifications",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SalusNotifications", targets: ["SalusNotifications"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SalusNotifications",
            dependencies: []
        ),
        .testTarget(
            name: "SalusNotificationsTests",
            dependencies: [
                "SalusNotifications"
            ]
        )
    ]
)
