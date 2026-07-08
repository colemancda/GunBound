import SwiftUI
import GunBound
import GunBoundClient

/// Shown before the `GameScene` starts — collects login fields and, on
/// "Play", verifies the bundled asset archives are actually present and
/// decodable *before* handing off to SpriteKit, where a missing/corrupt
/// archive would otherwise just silently print to the console instead of
/// surfacing anything on screen.
struct LoginView: View {
    @AppStorage("login.username") 
    private var username = "admin"
    @AppStorage("login.password") 
    private var password = "1234"
    @AppStorage("login.serverIP") 
    private var serverIP = "127.0.0.1"
    @State private var errorMessage: String?
    @State private var assetsDirectory: URL?

    var body: some View {
        Group {
            if let assetsDirectory {
                GameSceneView(
                    assetsDirectory: assetsDirectory,
                    network: NetworkConfig(
                        username: username,
                        password: password,
                        serverAddress: serverIP,
                        serverPort: 8370,
                        brokerPort: 8372
                    )
                )
                .ignoresSafeArea()
#if os(iOS)
                .statusBarHidden()
#endif
            } else {
                form
            }
        }
        .alert(
            "Couldn't load game assets",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }),
            presenting: errorMessage
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    private var form: some View {
        Form {
            Section("Login") {
                TextField("Username", text: $username)
                    .autocorrectionDisabled()
#if !os(macOS)
                    .textInputAutocapitalization(.never)
#endif
                SecureField("Password", text: $password)
                TextField("Server IP", text: $serverIP)
                    .autocorrectionDisabled()
#if !os(macOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.numbersAndPunctuation)
#endif
            }
            Section {
                Button("Play") { play() }
            }
        }
        .navigationTitle("GunBound")
    }

    private func play() {
        do {
            let directory = try Self.locateAssetsDirectory()
            // Sanity-check that the archive is actually readable and
            // contains real image data, not just that the file exists —
            // decoding `server_back.img` exercises the same XFS + LZHUF +
            // ImgFile path every screen depends on.
            let assets = AssetLibrary(directory: directory)
            _ = try assets.firstImageFrame(named: "server_back.img")
            assetsDirectory = directory
        } catch {
            errorMessage = Self.describe(error)
        }
    }

    /// Finds the directory holding the game archives. `copy-dependencies.sh`
    /// copies them into `AppModule/Resources/`, but SwiftPM's `.copy` can
    /// surface that in a few shapes depending on the build system (flattened
    /// into the bundle root, kept as a `Resources/` subfolder, or an older
    /// `orig/` subfolder), so every plausible location is checked for
    /// `graphics.xfs` — not just that a directory exists.
    private static func locateAssetsDirectory() throws -> URL {
        guard let resourceURL = Bundle.main.resourceURL else {
            throw AssetsError.missingBundleResourceURL
        }
        var candidates = [
            resourceURL.appendingPathComponent("Resources", isDirectory: true),
            resourceURL,
            resourceURL.appendingPathComponent("Resources/orig", isDirectory: true),
            resourceURL.appendingPathComponent("orig", isDirectory: true)
        ]
        #if os(macOS)
        // macOS has a real filesystem to read — fall back to the decomp
        // checkout path GunBoundSDL3 also defaults to, for running without
        // bundled assets.
        candidates.append(
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Developer/GunBound-Decomp/orig", isDirectory: true)
        )
        #endif
        for candidate in candidates {
            if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("graphics.xfs").path) {
                return candidate
            }
        }
        throw AssetsError.missingArchives(searched: candidates)
    }

    private enum AssetsError: Swift.Error {
        case missingBundleResourceURL
        case missingArchives(searched: [URL])
    }

    private static func describe(_ error: Swift.Error) -> String {
        switch error {
        case AssetsError.missingBundleResourceURL:
            return "The app bundle has no resource URL."
        case AssetsError.missingArchives(let searched):
            let paths = searched.map(\.path).joined(separator: "\n")
            return "graphics.xfs wasn't found in any of:\n\(paths)\n\nRun Darwin/copy-dependencies.sh to copy the archives into AppModule/Resources/ (see this Playground's README) and rebuild."
        default:
            return "\(error)"
        }
    }
}

#Preview {
    LoginView()
}
