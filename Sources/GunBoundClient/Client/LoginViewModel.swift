import Foundation
import Combine
import GunBound
import GunBoundFile
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Logic for the SwiftUI login screen — the pre-game front door every Apple
/// front end (iOS Playground, GunBound-macOS/-iOS/-tvOS) shares. On load it
/// locates the game archives and decodes the title art for the backdrop;
/// "Play" then hands the validated assets directory to the game scene.
///
/// Decoding the backdrop doubles as the sanity check that the whole
/// XFS + LZHUF + `ImgFile` pipeline actually works before handing off to
/// SpriteKit, where a missing/corrupt archive would otherwise just print to
/// the console with nothing visible on screen.
///
/// Not part of the in-game `ClientMode`/`GameScreen` state machine — login
/// happens before the engine starts (the original client took credentials
/// from its launcher rather than drawing a login screen).
@MainActor
public final class LoginViewModel: ObservableObject {

    /// The art drawn behind the login form — the title screen's
    /// "GunBound: Thor's Hammer" artwork.
    public static let backgroundImageName = "titlemode.img"

    /// Whether the on-load resource discovery/decode is still running (the
    /// view disables Play while true).
    @Published public private(set) var isLoading = false

    /// The directory containing `graphics.xfs` etc., once found and proven
    /// decodable — what "Play" hands to the game scene.
    @Published public private(set) var assetsDirectory: URL?

    #if canImport(CoreGraphics)
    /// The decoded login backdrop.
    @Published public private(set) var backgroundImage: CGImage?
    #endif

    /// Why loading failed, phrased for the Play button's alert; `nil` while
    /// loading or once loaded successfully.
    @Published public private(set) var loadFailureMessage: String?

    private let searchPaths: [URL]

    /// - Parameter searchPaths: where to look for the archives; defaults to
    ///   the app bundle's plausible layouts (plus, on macOS, the decomp
    ///   checkout path `GunBoundSDL3` also reads). Injectable for tests.
    public init(searchPaths: [URL]? = nil) {
        self.searchPaths = searchPaths ?? Self.defaultSearchPaths()
    }

    /// Locates the archives and decodes the backdrop. Call from the view's
    /// `.task` — the archive read/decode (graphics.xfs is ~200 MB) runs off
    /// the main actor. Idempotent: re-invocations while loaded/loading are
    /// no-ops.
    public func load() async {
        guard assetsDirectory == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let candidates = searchPaths
        guard let directory = Self.locateAssetsDirectory(searching: candidates) else {
            let paths = candidates.map(\.path).joined(separator: "\n")
            loadFailureMessage = "graphics.xfs wasn't found in any of:\n\(paths)\n\nRun Darwin/copy-dependencies.sh to copy the archives into AppModule/Resources/ (see the Playground's README) and rebuild."
            return
        }

        // Decode the backdrop off the main actor; the AssetLibrary (and the
        // ~200 MB archive buffer it holds) is discarded once the frame is
        // extracted — the game scene builds its own library later.
        let decoded: ImgFile.Frame? = await Task.detached(priority: .userInitiated) {
            let assets = AssetLibrary(directory: directory)
            return try? assets.firstImageFrame(named: Self.backgroundImageName)
        }.value

        guard let decoded else {
            loadFailureMessage = "Found \(directory.path), but couldn't decode \(Self.backgroundImageName) from graphics.xfs — the archive may be truncated or from an incompatible client version."
            return
        }

        #if canImport(CoreGraphics)
        backgroundImage = decoded.cgImage
        #endif
        loadFailureMessage = nil
        assetsDirectory = directory
    }

    /// The first candidate that actually contains `graphics.xfs` — not just
    /// a directory that exists.
    static func locateAssetsDirectory(searching candidates: [URL]) -> URL? {
        candidates.first {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent("graphics.xfs").path)
        }
    }

    /// Every plausible place the bundled archives can land — SwiftPM's
    /// `.copy` and Xcode folder references surface the copied folder in
    /// different shapes depending on the build system.
    static func defaultSearchPaths() -> [URL] {
        var candidates: [URL] = []
        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(resourceURL)
            candidates.append(resourceURL.appendingPathComponent("Resources", isDirectory: true))
            candidates.append(resourceURL.appendingPathComponent("Resources/orig", isDirectory: true))
            candidates.append(resourceURL.appendingPathComponent("orig", isDirectory: true))
        }
        #if os(macOS)
        // macOS has a real filesystem to read — fall back to the decomp
        // checkout path GunBoundSDL3 also defaults to, for running without
        // bundled assets.
        candidates.append(
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Developer/GunBound-Decomp/orig", isDirectory: true)
        )
        #endif
        return candidates
    }
}
