import SwiftUI
import GunBound
import GunBoundClient

/// Shown before the `GameScene` starts — collects login fields over the
/// title-screen artwork. Resource discovery lives in `LoginViewModel`
/// (GunBoundClient): on appear it locates the bundled game archives and
/// decodes `titlemode.img` for the backdrop, which doubles as the sanity
/// check that the whole XFS + LZHUF + ImgFile pipeline works *before*
/// handing off to SpriteKit — a missing/corrupt archive surfaces as an
/// alert on Play instead of a silent console print.
struct LoginView: View {
    @AppStorage("login.username")
    private var username = "admin"
    @AppStorage("login.password")
    private var password = "1234"
    @AppStorage("login.serverIP")
    private var serverIP = "127.0.0.1"
    @StateObject private var viewModel = LoginViewModel()
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
                    ),
                    // Server Select's EXIT button — leave the game and come
                    // back to this login screen (apps can't self-terminate
                    // on iOS/tvOS).
                    onQuit: { self.assetsDirectory = nil }
                )
                .ignoresSafeArea()
#if os(iOS)
                .statusBarHidden()
#endif
            } else {
                loginScreen
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
        .frame(minWidth: 800, minHeight: 600)
    }

    private var loginScreen: some View {
        Group {
            if viewModel.backgroundImage == nil {
                ProgressView()
            } else {
                ZStack {
                    background
                    form
                        .padding()
#if !os(tvOS)
                        .scrollContentBackground(.hidden)  // unavailable on tvOS
#endif
                        .frame(maxWidth: 440, maxHeight: 320)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .padding()
                }
            }
        }
        .task { await viewModel.load() }
    }

    /// The title art once the view model has decoded it; plain black while
    /// loading (or if the assets are missing).
    @ViewBuilder
    private var background: some View {
        Color.black.ignoresSafeArea()
        if let image = viewModel.backgroundImage {
            Image(decorative: image, scale: 1)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
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
                    .disabled(viewModel.isLoading)
            }
        }
        .navigationTitle("GunBound")
    }

    private func play() {
        if let directory = viewModel.assetsDirectory {
            assetsDirectory = directory
        } else {
            errorMessage = viewModel.loadFailureMessage
                ?? "Still loading game assets — try again in a moment."
        }
    }
}

#Preview {
    LoginView()
}
