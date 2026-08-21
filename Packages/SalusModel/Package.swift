// swift-tools-version: 6.0

// LINT GUARD: SalusModel is the pure-domain layer (mirrors Android :core:model,
// which links no UI framework). It must never import SwiftUI or UIKit, directly or
// transitively. Enforced by a SwiftLint custom rule added in Task 6.
// Mirrors Android module `:core:model`.

import PackageDescription

let package = Package(
    name: "SalusModel",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SalusModel", targets: ["SalusModel"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SalusModel",
            dependencies: []
        ),
        .testTarget(
            name: "SalusModelTests",
            dependencies: [
                "SalusModel"
            ]
        )
    ]
)
