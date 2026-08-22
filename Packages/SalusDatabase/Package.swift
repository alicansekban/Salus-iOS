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
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.11.1")
    ],
    targets: [
        .target(
            name: "SalusDatabase",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        ),
        .testTarget(
            name: "SalusDatabaseTests",
            dependencies: [
                "SalusDatabase"
            ]
        )
    ]
)
