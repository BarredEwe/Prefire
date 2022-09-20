// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Prefire",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "Prefire",
            targets: ["Prefire"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-snapshot-testing.git",
            from: "1.9.0"
        )
    ],
    targets: [
        .target(
            name: "Prefire",
            dependencies: [],
            exclude: ["Templates/"]
        ),
        .testTarget(
            name: "PrefireTests",
            dependencies: [
                "Prefire",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ]
        ),
    ]
)
