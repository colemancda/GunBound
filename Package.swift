// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GunBound",
    platforms: [
        .macOS("13.0")
    ],
    products: [
        .executable(
            name: "GunBoundServer",
            targets: ["GunBoundServer"]
        ),
        .library(
            name: "GunBound",
            targets: ["GunBound"]
        )
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(
            url: "https://github.com/PureSwift/Socket",
            branch: "main"
        ),
        .package(
            url: "https://github.com/apple/swift-argument-parser",
            from: "1.2.0"
        ),
        .package(
            url: "https://github.com/apple/swift-algorithms.git",
            from: "1.0.0"
        )
    ],
    targets: [
        .target(
            name: "GunBound",
            dependencies: [
                "Socket",
                .product(
                    name: "Algorithms",
                    package: "swift-algorithms"
                )
            ]
        ),
        .executableTarget(
            name: "GunBoundServer",
            dependencies: [
                "GunBound",
                .product(
                    name: "ArgumentParser",
                    package: "swift-argument-parser"
                ),
            ]
        ),
        .testTarget(
            name: "GunBoundTests",
            dependencies: ["GunBound"]
        )
    ]
)
