// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Prefire",
    platforms: [.iOS(.v14), .macOS(.v13), .watchOS(.v7)],
    products: [
        .library(name: "PrefireVoiceOver", targets: ["PrefireVoiceOver"]),
        .library(
            name: "Prefire",
            targets: ["Prefire"]
        ),
        .plugin(
            name: "PrefirePlaybookPlugin",
            targets: ["PrefirePlaybookPlugin"]
        ),
        .plugin(
            name: "PrefireTestsPlugin",
            targets: ["PrefireTestsPlugin"]
        ),
        .executable(
            name: "prefire",
            targets: ["PrefireCLI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/cashapp/AccessibilitySnapshot.git", from: "0.13.0"),
    ],
    targets: [
        .target(
            name: "PrefireVoiceOver",
            dependencies: [
                "Prefire",
                .product(
                    name: "AccessibilitySnapshotParser",
                    package: "AccessibilitySnapshot",
                    condition: .when(platforms: [.iOS])
                ),
            ]
        ),
        .target(
            name: "Prefire",
            dependencies: []
        ),
        .executableTarget(
            name: "PrefireCLI",
            resources: [
                .copy("../../Binaries/PrefireBinary.artifactbundle"),
            ]
        ),
        .testTarget(
            name: "PrefireCLITests",
            dependencies: ["PrefireCLI", "Prefire"]
        ),
        .plugin(
            name: "PrefirePlaybookPlugin",
            capability: .buildTool(),
            dependencies: [
                "PrefireBinary",
            ]
        ),
        .plugin(
            name: "PrefireTestsPlugin",
            capability: .buildTool(),
            dependencies: [
                "PrefireBinary",
            ]
        ),
        .binaryTarget(
            name: "PrefireBinary",
            path: "Binaries/PrefireBinary.artifactbundle"
        ),
    ]
)
