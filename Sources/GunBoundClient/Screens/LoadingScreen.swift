import CSDL3
import SDL3Swift
import GunBound

/// View for the Loading screen (state 10) — the fixed-duration timer lives
/// in `LoadingViewModel`; this loads/draws `load_back.img`/
/// `load_stage00.img`.
@MainActor
final class LoadingScreen: GameScreen {
    private let viewModel: LoadingViewModel
    private let visuals = ScreenRenderHelper()
    private var stageOverlayTexture: SDLTexture?

    init(viewModel: LoadingViewModel) {
        self.viewModel = viewModel
    }

    func onEnter(context: ScreenContext) throws {
        viewModel.onEnter()
        visuals.loadBackground(named: viewModel.backgroundImageName, context: context)
        stageOverlayTexture = visuals.loadTexture(named: viewModel.stageOverlayImageName, context: context)
    }

    func onExit() {
        viewModel.onExit()
        visuals.unloadBackground()
        stageOverlayTexture = nil
    }

    func handleEvent(_ event: SDLEvent, context: ScreenContext) {
        guard let input = translate(event) else { return }
        viewModel.handle(input)
    }

    func update(deltaTime: Double, context: ScreenContext) {
        viewModel.update(deltaTime: deltaTime)
    }

    func render(_ renderer: SDLRenderer) throws {
        try visuals.clearAndDrawBackground(renderer)
        if let stageOverlayTexture {
            try renderer.copy(stageOverlayTexture, destination: nativeRect(of: stageOverlayTexture))
        }
    }
}
