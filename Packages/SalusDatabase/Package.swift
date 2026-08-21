// swift-tools-version: 6.0

// Mirrors Android module `:core:database`.

import PackageDescription

let package = Package(
    name: "SalusDatabase",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SalusDatabase", targets: ["SalusDatabase"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SalusDatabase",
            dependencies: []
        ),
        .testTarget(
            name: "SalusDatabaseTests",
            dependencies: [
                "SalusDatabase"
            ]
        )
    ]
)
