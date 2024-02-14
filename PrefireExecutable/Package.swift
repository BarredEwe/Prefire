// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PrefireExecutable",
    platforms: [.macOS(.v13)],
    products: [
        .executable(
            name: "prefire",
            targets: ["prefire"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMinor(from: "1.2.0")),
    ],
    targets: [
        .executableTarget(
            name: "prefire",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "PrefireSourcery",
            ]
        ),
        .testTarget(
            name: "PrefireTests",
            dependencies: ["prefire"]
        ),
        .binaryTarget(
            name: "PrefireSourcery",
            path: "Binaries/PrefireSourcery.artifactbundle"
        ),
    ]
)
