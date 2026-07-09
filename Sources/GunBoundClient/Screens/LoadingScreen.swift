import GunBound

/// View for the Loading screen (state 10). Draws the `load_back.img` backdrop
/// and the room's map-specific `load_stageNN.img` overlay, then a per-player
/// ready row that flips each roster slot from "…" to "READY" as loading
/// progresses (the timer/progress lives in `LoadingViewModel`). The original's
/// per-player mobile-icon animation is deferred with the battle-render work.
@MainActor
public final class LoadingScreen: GameScreen {
    private let viewModel: LoadingViewModel
    private var backgroundTexture: ClientTexture?
    private var stageOverlayTexture: ClientTexture?
    private var font: LoadedFont?

    public init(viewModel: LoadingViewModel) {
        self.viewModel = viewModel
    }

    public func onEnter(context: ClientContext) throws {
        viewModel.onEnter()
        backgroundTexture = context.renderer.texture(named: viewModel.backgroundImageName, assets: context.assets)
        stageOverlayTexture = context.renderer.texture(named: viewModel.stageOverlayImageName, assets: context.assets)
        font = LoadedFont(.latinFont, renderer: context.renderer, assets: context.assets)
    }

    public func onExit() {
        viewModel.onExit()
        backgroundTexture = nil
        stageOverlayTexture = nil
        font = nil
    }

    public func handleInput(_ event: ScreenInputEvent) {
        viewModel.handle(event)
    }

    public func update(deltaTime: Double) {
        viewModel.update(deltaTime: deltaTime)
    }

    public func render(_ renderer: ClientRenderer) throws {
        renderer.clear()
        drawFullSize(backgroundTexture, using: renderer)
        drawFullSize(stageOverlayTexture, using: renderer)

        guard let font else { return }
        // Per-player ready row along the bottom.
        var y: Float = 500
        for (index, player) in viewModel.players.enumerated() {
            let ready = viewModel.isReady(playerIndex: index)
            font.draw("\(player.username)", x: 40, y: y, using: renderer)
            font.draw(ready ? "READY" : "...", x: 260, y: y, using: renderer)
            y += 16
        }
    }
}
