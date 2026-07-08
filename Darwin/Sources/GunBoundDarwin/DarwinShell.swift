import Foundation
import SpriteKit
import GunBound

/// Shared plumbing for the Darwin app targets (`GunBound-macOS`,
/// `GunBound-tvOS`): finds the game archives and builds the configured
/// `GameScene` — the Darwin equivalent of `GunBoundSDL3`'s argument parsing
/// and the iOS Playground's `LoginView` asset check.
enum DarwinShell {

    /// Where the game archives live. Checks the app bundle first (both
    /// targets copy the Playground's `AppModule/Resources` folder in, so the
    /// same layouts `LoginView` handles apply), then — macOS only, where
    /// there's a real filesystem to read — the decomp checkout path
    /// `GunBoundSDL3` also defaults to, as a fallback.
    static func locateAssetsDirectory() -> URL? {
        var candidates: [URL] = []
        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(resourceURL.appendingPathComponent("Resources", isDirectory: true))
            candidates.append(resourceURL)
            candidates.append(resourceURL.appendingPathComponent("Resources/orig", isDirectory: true))
            candidates.append(resourceURL.appendingPathComponent("orig", isDirectory: true))
        }
        #if os(macOS)
        candidates.append(
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Developer/GunBound-Decomp/orig", isDirectory: true)
        )
        #endif
        return candidates.first {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent("graphics.xfs").path)
        }
    }

    /// Login/server configuration — read from `UserDefaults` under the same
    /// keys the iOS Playground's `LoginView` persists via `@AppStorage`, with
    /// the same defaults, so all the Darwin front ends share one convention
    /// (`defaults write org.pureswift.GunBound.macos login.serverIP …` to
    /// point at a real server).
    static func networkConfig() -> NetworkConfig {
        let defaults = UserDefaults.standard
        return NetworkConfig(
            username: defaults.string(forKey: "login.username") ?? "admin",
            password: defaults.string(forKey: "login.password") ?? "1234",
            serverAddress: defaults.string(forKey: "login.serverIP") ?? "127.0.0.1",
            serverPort: 8370,
            brokerPort: 8372
        )
    }

    /// Builds the configured 800×600 `GameScene`, or `nil` (with a logged
    /// explanation) when the game archives can't be found.
    @MainActor
    static func makeScene() -> GameScene? {
        guard let assetsDirectory = locateAssetsDirectory() else {
            print("[GunBoundDarwin] graphics.xfs not found — bundle the assets (run Playgrounds/copy-dependencies.sh before building) or place them at ~/Developer/GunBound-Decomp/orig")
            return nil
        }
        let scene = GameScene()
        scene.scaleMode = .aspectFit
        scene.assetsDirectory = assetsDirectory
        scene.network = networkConfig()
        return scene
    }
}
