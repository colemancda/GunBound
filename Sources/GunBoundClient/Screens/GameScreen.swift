import SDL3Swift
import SDL3Mixer
import GunBound

/// One screen in the client's state machine, mirroring the original client's
/// `CGameState` per-state virtuals (`OnEnter`/`OnExit`, per-frame render) —
/// see `ARCHITECTURE.md`'s "The 16 game states" table in the decomp repo.
///
/// A `GameScreen` is a thin SDL view: it owns a `ScreenViewModel` (defined in
/// the `GunBound` module, with zero SDL/rendering dependency) that holds all
/// navigation/business logic and state, and this protocol's job is just to
/// translate SDL events into `ScreenInputEvent`s for the view model, load
/// whatever named resources the view model exposes into textures/audio, and
/// draw them each frame.
@MainActor
protocol GameScreen: AnyObject {
    /// Loads this screen's named `.img`/`.mp3` resources (as exposed by its
    /// view model) and starts its music, matching the original's `OnEnter`
    /// resource-load convention.
    func onEnter(context: ScreenContext) throws
    func onExit()
    func handleEvent(_ event: SDLEvent, context: ScreenContext)
    func update(deltaTime: Double, context: ScreenContext)
    func render(_ renderer: SDLRenderer) throws
}

/// Shared services every screen needs: asset access and a way to request the
/// next screen — mirrors the original's `g_pendingGameState`/
/// `g_stateChangeRequested` two-step (request now, swap between frames).
/// Conforms to `ViewModelDelegate` so every `ScreenViewModel` can request
/// transitions and reach the network config/client without knowing anything
/// about SDL.
@MainActor
final class ScreenContext: ViewModelDelegate {
    let assets: AssetLibrary
    let renderer: SDLRenderer
    let mixer: SDLMixer
    let network: NetworkConfig
    var client: NetworkClient?
    private(set) var pendingMode: ClientMode?

    init(assets: AssetLibrary, renderer: SDLRenderer, mixer: SDLMixer, network: NetworkConfig) {
        self.assets = assets
        self.renderer = renderer
        self.mixer = mixer
        self.network = network
    }

    func requestTransition(to mode: ClientMode) {
        pendingMode = mode
    }

    fileprivate func consumePendingTransition() -> ClientMode? {
        defer { pendingMode = nil }
        return pendingMode
    }
}

/// Drives the current screen and swaps to the next one once requested,
/// logging each transition (Logo1 -> Logo2 -> Title -> ServerSelect ->
/// RoomList) so the flow can be verified from the console.
@MainActor
final class GameStateMachine {
    private let context: ScreenContext
    private let makeScreen: (ClientMode) -> GameScreen?
    private(set) var current: GameScreen

    init(context: ScreenContext, initialMode: ClientMode, makeScreen: @escaping (ClientMode) -> GameScreen?) throws {
        self.context = context
        self.makeScreen = makeScreen
        guard let screen = makeScreen(initialMode) else {
            fatalError("No screen registered for initial mode \(initialMode)")
        }
        self.current = screen
        print("[GunBoundClient] entering screen: \(initialMode)")
        try current.onEnter(context: context)
    }

    func handleEvent(_ event: SDLEvent) {
        current.handleEvent(event, context: context)
    }

    func update(deltaTime: Double) throws {
        current.update(deltaTime: deltaTime, context: context)
        if let nextMode = context.consumePendingTransition() {
            guard let nextScreen = makeScreen(nextMode) else {
                print("[GunBoundClient] no screen registered for mode \(nextMode), ignoring transition")
                return
            }
            current.onExit()
            current = nextScreen
            print("[GunBoundClient] entering screen: \(nextMode)")
            try current.onEnter(context: context)
        }
    }

    func render() throws {
        try current.render(context.renderer)
        context.renderer.present()
    }
}
