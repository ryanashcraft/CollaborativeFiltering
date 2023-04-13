// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CollaborativeFiltering",
    platforms: [
        .macOS(.v10_13),
        .iOS(.v12),
        .tvOS(.v12),
        .watchOS(.v6),
    ],
    products: [
        .library(
            name: "CollaborativeFiltering",
            targets: ["CollaborativeFiltering"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/AlexanderTar/LASwift.git", from: "0.3.2"),
    ],
    targets: [
        .target(
            name: "CollaborativeFiltering",
            dependencies: ["LASwift"]
        ),
        .testTarget(
            name: "CollaborativeFilteringTests",
            dependencies: ["CollaborativeFiltering"]
        ),
    ]
)
