// swift-tools-version: 6.0
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
            targets: ["PrefireBinary"]
        ),
    ],
    targets: [
        .target(
            name: "Prefire",
            dependencies: []
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
