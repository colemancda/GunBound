// swift-tools-version: 6.0

// Self-contained manifest for running on iPad (Swift Playgrounds).
//
// The GunBound library targets AND swift-binary-parsing are VENDORED into this
// bundle (as sibling folders to AppModule/) rather than referenced via a
// `.package(path: "../..")` local dependency, which isn't reachable once the
// .swiftpm is copied to an iPad. `swift-binary-parsing` is vendored with its
// `BinaryParsingMacros` swift-syntax compiler-plugin removed, because Swift
// Playgrounds can't build macro plugins (the `#magicNumber` macro it provides
// is unused). Run `Playgrounds/copy-dependencies.sh` to (re)populate the
// vendored folders and the game assets — they're gitignored. The remaining
// third-party packages are pulled by URL and resolved over the network.

import PackageDescription
import AppleProductTypes

// GunBound / GunBoundClient need Swift 5 language mode (their concurrency
// annotations predate strict Swift 6 checking); the rest build under Swift 6.
let v5: [SwiftSetting] = [.swiftLanguageMode(.v5)]

let package = Package(
    name: "GunBoundSpriteKit",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "GunBoundSpriteKit",
            targets: ["AppModule"],
            bundleIdentifier: "org.pureswift.GunBoundSpriteKit",
            teamIdentifier: "4W79SG34MW",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .star),
            accentColor: .presetColor(.indigo),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft
            ],
            capabilities: [
                .outgoingNetworkConnections()
            ]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/PureSwift/Socket",
            from: "0.5.2"
        ),
        .package(
            url: "https://github.com/krzyzanowskim/CryptoSwift.git",
            .upToNextMajor(from: "1.6.0")
        ),
        .package(
            url: "https://github.com/apple/swift-argument-parser",
            from: "1.2.0"
        )
    ],
    targets: [
        // Vendored dependency sources — populated by copy-dependencies.sh.
        .target(
            name: "BinaryParsing",
            path: "BinaryParsing",
            swiftSettings: [.enableExperimentalFeature("Lifetimes")]
        ),
        .target(
            name: "GunBoundProtocol",
            dependencies: ["BinaryParsing"],
            path: "GunBoundProtocol"
        ),
        .target(
            name: "GunBoundFile",
            dependencies: ["BinaryParsing"],
            path: "GunBoundFile"
        ),
        .target(
            name: "GunBound",
            dependencies: [
                "GunBoundProtocol",
                .product(name: "Socket", package: "Socket"),
                .product(name: "CryptoSwift", package: "CryptoSwift"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "GunBound",
            swiftSettings: v5
        ),
        .target(
            name: "GunBoundClient",
            dependencies: [
                "GunBound",
                "GunBoundProtocol",
                "GunBoundFile"
            ],
            path: "GunBoundClient",
            swiftSettings: v5
        ),
        .executableTarget(
            name: "AppModule",
            dependencies: [
                "GunBound",
                "GunBoundProtocol",
                "GunBoundFile",
                "GunBoundClient"
            ],
            path: "AppModule",
            resources: [
                .copy("Resources")
            ],
            swiftSettings: v5
        )
    ]
)
