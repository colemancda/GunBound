import GunBound

/// View for the Loading screen (state 10) — the fixed-duration timer lives
/// in `LoadingViewModel`; this loads/draws `load_back.img`/
/// `load_stage00.img`.
@MainActor
public final class LoadingScreen: GameScreen {
    private let viewModel: LoadingViewModel
    private var backgroundTexture: ClientTexture?
    private var stageOverlayTexture: ClientTexture?

    public init(viewModel: LoadingViewModel) {
        self.viewModel = viewModel
    }

    public func onEnter(context: ClientContext) throws {
        viewModel.onEnter()
        backgroundTexture = context.renderer.texture(named: viewModel.backgroundImageName, assets: context.assets)
        stageOverlayTexture = context.renderer.texture(named: viewModel.stageOverlayImageName, assets: context.assets)
    }

    public func onExit() {
        viewModel.onExit()
        backgroundTexture = nil
        stageOverlayTexture = nil
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
    }
}
