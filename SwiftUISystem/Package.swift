// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftUISystem",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "SwiftUISystem",
            targets: ["SwiftUISystem"]
        ),
    ],
    targets: [
        .target(
            name: "SwiftUISystem",
            dependencies: [],
            exclude: ["Templates/"]
        ),
        .testTarget(
            name: "SwiftUISystemTests",
            dependencies: ["SwiftUISystem"]
        ),
    ]
)
