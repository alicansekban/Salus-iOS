// swift-tools-version: 6.0

// Mirrors Android module `:core:reminder`.

import PackageDescription

let package = Package(
    name: "SalusReminder",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SalusReminder", targets: ["SalusReminder"])
    ],
    dependencies: [
        .package(path: "../SalusModel"),
        .package(path: "../SalusCommon"),
        .package(path: "../SalusDatabase"),
        .package(path: "../SalusNotifications")
    ],
    targets: [
        .target(
            name: "SalusReminder",
            dependencies: [
                .product(name: "SalusModel", package: "SalusModel"),
                .product(name: "SalusCommon", package: "SalusCommon"),
                .product(name: "SalusDatabase", package: "SalusDatabase"),
                .product(name: "SalusNotifications", package: "SalusNotifications")
            ]
        ),
        .testTarget(
            name: "SalusReminderTests",
            dependencies: [
                "SalusReminder"
            ]
        )
    ]
)
