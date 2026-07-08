// swift-tools-version: 5.9

// Self-contained manifest for running on iPad (Swift Playgrounds).
//
// The GunBound library targets are VENDORED into this bundle (as sibling
// folders to AppModule/) rather than referenced via a `.package(path: "../..")`
// local dependency, which isn't reachable once the .swiftpm is copied to an
// iPad. Run `Playgrounds/copy-dependencies.sh` to (re)populate those folders
// and the game assets — they're gitignored. The third-party packages are
// pulled by URL and resolved over the network by Swift Playgrounds.

import PackageDescription
import AppleProductTypes

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
        ),
        .package(
            url: "https://github.com/apple/swift-binary-parsing",
            .upToNextMinor(from: "0.0.2")
        )
    ],
    targets: [
        // Vendored library targets — populated by copy-dependencies.sh.
        .target(
            name: "GunBoundProtocol",
            dependencies: [
                .product(name: "BinaryParsing", package: "swift-binary-parsing")
            ],
            path: "GunBoundProtocol"
        ),
        .target(
            name: "GunBoundFile",
            dependencies: [
                .product(name: "BinaryParsing", package: "swift-binary-parsing")
            ],
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
            path: "GunBound"
        ),
        .target(
            name: "GunBoundClient",
            dependencies: [
                "GunBound",
                "GunBoundProtocol",
                "GunBoundFile"
            ],
            path: "GunBoundClient"
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
            ]
        )
    ]
)
