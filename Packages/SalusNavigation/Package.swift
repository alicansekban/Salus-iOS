// swift-tools-version: 6.0

// Mirrors Android module `:core:navigation`.

import PackageDescription

let package = Package(
    name: "SalusNavigation",
    // `.macOS(.v14)` is a test-host concession, not a target (CLAUDE.md): `swift test` builds for
    // the host, and `TabBackStacks` is an `@Observable` holder of SwiftUI `NavigationPath`s — both
    // Observation and the `NavigationStack` path model are iOS 17 / macOS 14. Without the floor the
    // host build fails with "'Observable()' is only available in macOS 14.0 or newer". iOS 17
    // remains the ship target.
    platforms: [.iOS(.v17), .macOS(.v14)],
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
