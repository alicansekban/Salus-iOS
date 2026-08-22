// swift-tools-version: 6.0

// Mirrors Android module `:core:database`.

import PackageDescription

let package = Package(
    name: "SalusDatabase",
    // `.macOS(.v14)` is the project's usual test-host concession (see CLAUDE.md), reached here
    // for a reason unrelated to SwiftUI: GRDB's own manifest declares a macOS 10.15 floor, while
    // a manifest that names no macOS platform is treated by SwiftPM as macOS 10.13. `swift test`
    // builds for the host, so without this line every host build of this package fails with
    // "the library 'SalusDatabase' requires macos 10.13, but depends on the product 'GRDB' which
    // requires macos 10.15". iOS 17 remains the ship target; nothing here ever ships to macOS.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SalusDatabase", targets: ["SalusDatabase"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.11.1"),
        .package(path: "../SalusCommon"),
        .package(path: "../SalusTesting")
    ],
    targets: [
        .target(
            name: "SalusDatabase",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                // The seeded default profile's `created_at` comes from the injected clock, the
                // twin of Android's `System.currentTimeMillis()` in `SeedDefaultProfileCallback`.
                .product(name: "SalusCommon", package: "SalusCommon")
            ]
        ),
        .testTarget(
            name: "SalusDatabaseTests",
            dependencies: [
                "SalusDatabase",
                // Test-target only, and it stays that way: the library must never link the
                // fixtures. `FixedSalusClock` is what makes the seeded `created_at` assertable.
                .product(name: "SalusTesting", package: "SalusTesting")
            ],
            // Verbatim copies of Room's schema export — the contract `RoomSchemaParityTests`
            // checks the migrator against. `.copy` keeps the directory (and the bytes) intact;
            // `.process` would be free to rewrite or flatten them.
            resources: [.copy("Resources/RoomSchemas")]
        )
    ]
)
