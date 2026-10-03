// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

/// Renders previews on the iOS Simulator and compares them with what SnapshotTesting renders.
///
/// A package of its own, so SnapshotTesting stays out of the dependencies of the Prefire library.
/// Run it with `make test-ios`.
let package = Package(
    name: "PrefireSnapshotTests",
    platforms: [.iOS(.v15)],
    dependencies: [
        .package(name: "Prefire", path: "../"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0"),
    ],
    targets: [
        .testTarget(
            name: "PrefireSnapshotTests",
            dependencies: [
                .product(name: "Prefire", package: "Prefire"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
    ]
)
