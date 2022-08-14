// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftUISystem",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "SwiftUISystem",
            targets: ["SwiftUISystem"]
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
            name: "SwiftUISystem",
            dependencies: [],
            exclude: ["Templates/"]
        ),
        .testTarget(
            name: "SwiftUISystemTests",
            dependencies: [
                "SwiftUISystem",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ]
        ),
    ]
)
