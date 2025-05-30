// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PrefireExample",
    platforms: [.iOS(.v17), .macOS(.v15)],
    products: [
        .library(
            name: "PrefireExample",
            targets: ["PrefireExample"]
        ),
    ],
    dependencies: [
        .package(
            name: "Prefire",
            path: "../"
        ),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.15.4")
    ],
    targets: [
        .target(
            name: "PrefireExample",
            dependencies: [
                "Prefire"
            ],
            path: "Shared",
            plugins: [
                .plugin(name: "PrefirePlaybookPlugin", package: "Prefire")
            ]
        ),
        .testTarget(
            name: "PrefireExampleTests",
            dependencies: [
                "PrefireExample",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "PrefireExampleTests",
            plugins: [
                .plugin(name: "PrefireTestsPlugin", package: "Prefire")
            ]
        )
    ]
)
