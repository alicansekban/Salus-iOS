// swift-tools-version: 6.0

// LINT GUARD: SalusCommon is pure domain support (mirrors Android :core:common).
// It must never import SwiftUI or UIKit, directly or transitively.
// Enforced by a SwiftLint custom rule added in Task 6.
// Mirrors Android module `:core:common`.

import PackageDescription

let package = Package(
    name: "SalusCommon",
    // `.macOS(.v14)` is a test-host concession, not a target (CLAUDE.md): `swift test` builds for
    // the host, and `PendingDeleteController` is `@Observable` — the Observation module is
    // iOS 17 / macOS 14. Without the floor the host build fails with "'Observable()' is only
    // available in macOS 14.0 or newer". It propagates to every dependent whose own host build
    // must succeed, which is why SalusSettings and SalusTesting carry the same line. iOS 17
    // remains the ship target.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SalusCommon", targets: ["SalusCommon"])
    ],
    dependencies: [
        .package(path: "../SalusModel")
    ],
    targets: [
        .target(
            name: "SalusCommon",
            dependencies: [
                .product(name: "SalusModel", package: "SalusModel")
            ]
        ),
        .testTarget(
            name: "SalusCommonTests",
            dependencies: [
                "SalusCommon"
            ]
        )
    ]
)
