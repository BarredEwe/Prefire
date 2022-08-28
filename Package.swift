// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PreFire",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "PreFire",
            targets: ["PreFire"]
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
            name: "PreFire",
            dependencies: [],
            exclude: ["Templates/"]
        ),
        .testTarget(
            name: "PreFireTests",
            dependencies: [
                "PreFire",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ]
        ),
    ]
)
