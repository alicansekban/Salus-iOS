// swift-tools-version: 6.0

// Mirrors Android module `:core:premium`.

import PackageDescription

let package = Package(
    name: "SalusPremium",
    // `.macOS(.v14)` is the project's usual test-host concession (see CLAUDE.md): `swift test`
    // builds for the host, and this package's `PremiumRepositoryImpl` is `@Observable` (macOS 14),
    // while `purchases-ios` declares a macOS 10.15 floor. iOS 17 remains the ship target; nothing
    // here ever ships to macOS.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SalusPremium", targets: ["SalusPremium"])
    ],
    dependencies: [
        .package(path: "../SalusModel"),
        .package(url: "https://github.com/RevenueCat/purchases-ios.git", from: "5.87.1")
    ],
    targets: [
        .target(
            name: "SalusPremium",
            dependencies: [
                .product(name: "SalusModel", package: "SalusModel"),
                .product(name: "RevenueCat", package: "purchases-ios")
            ]
        ),
        .testTarget(
            name: "SalusPremiumTests",
            dependencies: [
                "SalusPremium"
            ]
        )
    ]
)
