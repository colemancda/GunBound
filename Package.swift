// swift-tools-version: 6.2
import Foundation
import PackageDescription

// Building with `ENABLE_EMBEDDED=1 swift build --target GunBoundProtocol` compiles the
// packet/protocol layer under Embedded Swift, against swift-binary-parsing's Embedded-specific
// product. This is opt-in (rather than the default) because swift-binary-parsing only vends its
// `BinaryParsingEmbedded` product when its own manifest observes the same environment variable,
// and because Embedded Swift requires macOS 14 while the rest of the package (networking, which
// isn't embeddable) targets macOS 13.
let embedded = ProcessInfo.processInfo.environment["ENABLE_EMBEDDED"] != nil

let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v5)
]

// Applied to every Foundation-free, Embedded-Swift-capable target (GunBoundProtocol, GunBoundFile).
let embeddedSwiftSettings: [SwiftSetting] =
    embedded
    ? [
        .enableExperimentalFeature("Embedded"),
        .enableExperimentalFeature("Lifetimes"),
        .define("GUNBOUND_EMBEDDED"),
    ]
    : []

let package = Package(
    name: "GunBound",
    platforms: [
        .macOS(embedded ? "14.0" : "13.0")
    ],
    products: [
        .executable(
            name: "GunBoundServer",
            targets: ["GunBoundServer"]
        ),
        .library(
            name: "GunBound",
            targets: ["GunBound"]
        ),
        .library(
            name: "GunBoundProtocol",
            targets: ["GunBoundProtocol"]
        ),
        .library(
            name: "GunBoundFile",
            targets: ["GunBoundFile"]
        )
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(
            url: "https://github.com/PureSwift/Socket",
            branch: "main"
        ),
        .package(
            url: "https://github.com/krzyzanowskim/CryptoSwift.git",
            .upToNextMajor(from: "1.6.0")
        ),
        .package(
            url: "https://github.com/apple/swift-argument-parser",
            from: "1.2.0"
        ),
        .package(
            url: "https://github.com/apple/swift-binary-parsing",
            .upToNextMinor(from: "0.0.2")
        )
    ],
    targets: [
        .target(
            name: "GunBoundProtocol",
            dependencies: [
                .product(
                    name: embedded ? "BinaryParsingEmbedded" : "BinaryParsing",
                    package: "swift-binary-parsing"
                )
            ],
            swiftSettings: embeddedSwiftSettings
        ),
        .target(
            name: "GunBoundFile",
            dependencies: [
                .product(
                    name: embedded ? "BinaryParsingEmbedded" : "BinaryParsing",
                    package: "swift-binary-parsing"
                )
            ],
            swiftSettings: embeddedSwiftSettings
        ),
        .target(
            name: "GunBound",
            dependencies: [
                "GunBoundProtocol",
                "Socket",
                "CryptoSwift",
                .product(
                    name: "ArgumentParser",
                    package: "swift-argument-parser"
                )
            ],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "GunBoundServer",
            dependencies: [
                "GunBound",
                "GunBoundProtocol",
                .product(
                    name: "ArgumentParser",
                    package: "swift-argument-parser"
                )
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "GunBoundTests",
            dependencies: ["GunBound", "GunBoundProtocol"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "GunBoundFileTests",
            dependencies: ["GunBoundFile"],
            resources: [
                .copy("Resources")
            ],
            swiftSettings: swiftSettings
        )
    ]
)
