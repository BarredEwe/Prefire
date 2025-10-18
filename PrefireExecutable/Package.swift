// swift-tools-version: 6.0
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
        .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMinor(from: "1.2.3")),
        .package(url: "https://github.com/kylef/PathKit.git", .upToNextMinor(from: "1.0.1")),
        .package(url: "https://github.com/BarredEwe/Sourcery.git", revision: "ee2f3fc2bbcdd733dff0913f9db824372ef37b3d"),
    ],
    targets: [
        .target(
            name: "PrefireCore",
            dependencies: [
                .product(name: "SourceryFramework", package: "Sourcery"),
                .product(name: "SourceryRuntime", package: "Sourcery"),
                .product(name: "SourceryStencil", package: "Sourcery"),
                "PathKit"
            ]
        ),
        .executableTarget(
            name: "prefire",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "PrefireCore",
            ]
        ),
        .testTarget(
            name: "PrefireTests",
            dependencies: ["prefire"]
        ),
    ]
)
