// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

/// Tests of the Prefire library on the iOS Simulator: rendering previews, and comparing them with what
/// SnapshotTesting renders.
///
/// A package of its own, so the SnapshotTesting product stays out of the Prefire app target.
/// Run it with `make test-ios`.
let package = Package(
    name: "PrefireSnapshotTests",
    platforms: [.iOS(.v15)],
    dependencies: [
        .package(name: "Prefire", path: "../"),
        .package(url: "https://github.com/cashapp/AccessibilitySnapshot", from: "0.13.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0"),
    ],
    targets: [
        .testTarget(
            name: "PrefireSnapshotTests",
            dependencies: [
                .product(name: "Prefire", package: "Prefire"),
                .product(name: "PrefireVoiceOver", package: "Prefire"),
                .product(name: "AccessibilitySnapshot", package: "AccessibilitySnapshot"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
    ]
)
