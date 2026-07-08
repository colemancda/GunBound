import GunBound

/// Shared services every screen needs: asset access, a rendering backend, an
/// audio-player factory (each screen gets its own player instance), login
/// configuration, and a way to request the next screen — mirrors the
/// original client's `g_pendingGameState`/`g_stateChangeRequested` two-step
/// (request now, swap between frames). Conforms to `ViewModelDelegate` so
/// every `ScreenViewModel` can request transitions and reach the network
/// config/client without knowing anything about rendering.
@MainActor
public final class ClientContext: ViewModelDelegate {
    public let assets: AssetLibrary
    public let renderer: ClientRenderer
    public let network: NetworkConfig
    public var client: NetworkClient<GunBoundSocketIPv4TCP>?
    public let session = ClientSession()

    /// Set by `requestQuit()` (e.g. the Server Select screen's "Exit"
    /// button) — the host app's main loop polls this each frame and stops
    /// when it's `true`. Not every host can act on it (there's no real
    /// "quit" on iOS); ones that can't just never check it.
    public private(set) var quitRequested = false

    private let makeAudioPlayerClosure: () -> ClientAudioPlayer
    private(set) var pendingMode: ClientMode?

    public init(
        assets: AssetLibrary,
        renderer: ClientRenderer,
        network: NetworkConfig,
        makeAudioPlayer: @escaping () -> ClientAudioPlayer
    ) {
        self.assets = assets
        self.renderer = renderer
        self.network = network
        self.makeAudioPlayerClosure = makeAudioPlayer
    }

    /// A fresh audio player instance — screens each get their own rather
    /// than sharing one, since they independently start/stop their own
    /// music track as they're entered/exited.
    public func makeAudioPlayer() -> ClientAudioPlayer {
        makeAudioPlayerClosure()
    }

    public func requestTransition(to mode: ClientMode) {
        pendingMode = mode
    }

    public func requestQuit() {
        quitRequested = true
    }

    func consumePendingTransition() -> ClientMode? {
        defer { pendingMode = nil }
        return pendingMode
    }
}
