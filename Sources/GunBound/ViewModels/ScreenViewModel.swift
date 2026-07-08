/// One screen's logic and internal state, independent of any rendering
/// framework — mirrors the original client's `CGameState` per-state
/// virtuals (`OnEnter`/`OnExit`, per-frame update), but a `ScreenViewModel`
/// only ever exposes named resources (`.img`/`.mp3` identifiers) and
/// `Rect`-based layout/hit-testing state, never a texture, renderer, or
/// audio handle — a view (e.g. an SDL `GameScreen`) owns those and reads
/// this state to decide what to draw.
@MainActor
public protocol ScreenViewModel: AnyObject {
    /// Reset any per-visit state — the view loads this screen's named
    /// resources separately, once it knows how to turn them into textures.
    func onEnter()
    func onExit()
    func handle(_ event: ScreenInputEvent)
    func update(deltaTime: Double)
}

/// Shared services every view model needs: login configuration, a slot for
/// the connected `NetworkClient` once one exists, and a way to request the
/// next screen — mirrors the original client's `g_pendingGameState`/
/// `g_stateChangeRequested` two-step (request now, swap between frames).
@MainActor
public protocol ViewModelDelegate: AnyObject {
    var network: NetworkConfig { get }
    var client: NetworkClient<GunBoundSocketIPv4TCP>? { get set }
    func requestTransition(to mode: ClientMode)

    /// Requests that the app quit — e.g. the Server Select screen's "Exit"
    /// button. Not every backend can act on this (there's no real "quit" on
    /// iOS), so implementations that can't are free to no-op.
    func requestQuit()
}
