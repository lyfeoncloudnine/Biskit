// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Biskit",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "Biskit",
            targets: ["Biskit"]
        ),
    ],
    targets: [
        .target(
            name: "Biskit",
            dependencies: []
        ),
        .testTarget(
            name: "BiskitTests",
            dependencies: ["Biskit"]
        ),
    ]
)
