import GunBound

/// One screen in the client's state machine, mirroring the original client's
/// `CGameState` per-state virtuals (`OnEnter`/`OnExit`, per-frame render) —
/// see `ARCHITECTURE.md`'s "The 16 game states" table in the decomp repo.
///
/// A `GameScreen` is a thin view: it owns a `ScreenViewModel` (in the
/// `GunBound` module, with zero rendering dependency) that holds all
/// navigation/business logic and state, and this protocol's job is just to
/// load whatever named resources the view model exposes via `ClientRenderer`/
/// `ClientAudioPlayer` and draw them each frame — no `SDLEvent`, `SDLTexture`,
/// or any other backend-specific type appears here, which is what lets the
/// same screen implementation run under SDL3, SpriteKit, or any other
/// backend that implements `ClientRenderer`/`ClientAudioPlayer`.
@MainActor
public protocol GameScreen: AnyObject {
    /// Loads this screen's named `.img`/`.mp3` resources (as exposed by its
    /// view model) and starts its music, matching the original's `OnEnter`
    /// resource-load convention.
    func onEnter(context: ClientContext) throws
    func onExit()
    func handleInput(_ event: ScreenInputEvent)
    func update(deltaTime: Double)
    func render(_ renderer: ClientRenderer) throws
}
