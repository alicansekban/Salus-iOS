// swift-tools-version: 6.0

// Mirrors Android module `(new on both platforms)`.

import PackageDescription

let package = Package(
    name: "SalusBackup",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SalusBackup", targets: ["SalusBackup"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SalusBackup",
            dependencies: []
        ),
        .testTarget(
            name: "SalusBackupTests",
            dependencies: [
                "SalusBackup"
            ]
        )
    ]
)
