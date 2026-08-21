// swift-tools-version: 6.0

// Mirrors Android module `:core:designsystem`.

import PackageDescription

let package = Package(
    name: "SalusDesignSystem",
    // iOS is the ship target. macOS is declared only so `swift test` can build and run the
    // token pinning tests on the host toolchain — this package draws SwiftUI `Color`/`Font`
    // values, which need a macOS deployment target above 10.13 (SwiftPM's default).
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SalusDesignSystem", targets: ["SalusDesignSystem"])
    ],
    dependencies: [
        .package(path: "../SalusModel")
    ],
    targets: [
        .target(
            name: "SalusDesignSystem",
            dependencies: [
                .product(name: "SalusModel", package: "SalusModel")
            ]
        ),
        .testTarget(
            name: "SalusDesignSystemTests",
            dependencies: [
                "SalusDesignSystem",
                // The theme tests name `ThemeMode` / `PremiumTheme` directly. They come from the
                // pure-domain package, so the dependency is declared rather than relied on
                // transitively through `SalusDesignSystem`.
                .product(name: "SalusModel", package: "SalusModel")
            ]
        )
    ]
)
