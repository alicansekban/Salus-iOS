// swift-tools-version: 6.0

// Mirrors Android module `:core:profile`.

import PackageDescription

let package = Package(
    name: "SalusProfile",
    // Inherited test-host concession: this package links `SalusDatabase`, which must declare
    // macOS 14 to satisfy GRDB's macOS 10.15 floor on the host build. A dependent that names no
    // macOS platform is treated as macOS 10.13 and cannot link it. iOS 17 stays the ship target.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SalusProfile", targets: ["SalusProfile"])
    ],
    dependencies: [
        .package(path: "../SalusModel"),
        .package(path: "../SalusCommon"),
        .package(path: "../SalusDatabase")
    ],
    targets: [
        .target(
            name: "SalusProfile",
            dependencies: [
                .product(name: "SalusModel", package: "SalusModel"),
                .product(name: "SalusCommon", package: "SalusCommon"),
                .product(name: "SalusDatabase", package: "SalusDatabase")
            ]
        ),
        .testTarget(
            name: "SalusProfileTests",
            dependencies: [
                "SalusProfile"
            ]
        )
    ]
)
