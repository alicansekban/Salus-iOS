// swift-tools-version: 6.0

// Mirrors Android module `:core:reminder`.

import PackageDescription

let package = Package(
    name: "SalusReminder",
    // Inherited test-host concession: this package links `SalusDatabase`, which must declare
    // macOS 14 to satisfy GRDB's macOS 10.15 floor on the host build. A dependent that names no
    // macOS platform is treated as macOS 10.13 and cannot link it. iOS 17 stays the ship target.
    platforms: [.iOS(.v17), .macOS(.v14)],
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
