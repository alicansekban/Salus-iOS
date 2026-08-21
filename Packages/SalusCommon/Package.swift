// swift-tools-version: 6.0

// LINT GUARD: SalusCommon is pure domain support (mirrors Android :core:common).
// It must never import SwiftUI or UIKit, directly or transitively.
// Enforced by a SwiftLint custom rule added in Task 6.
// Mirrors Android module `:core:common`.

import PackageDescription

let package = Package(
    name: "SalusCommon",
    platforms: [.iOS(.v17)],
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
