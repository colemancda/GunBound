import SDL3Swift
import GunBound

/// View for the publisher splash screens (states 5/6) — all logic/timing
/// lives in `LogoViewModel`; this just loads/draws the named resources it
/// exposes and forwards input.
@MainActor
final class LogoScreen: GameScreen {
    private let viewModel: LogoViewModel
    private let visuals = ScreenRenderHelper()

    init(viewModel: LogoViewModel) {
        self.viewModel = viewModel
    }

    func onEnter(context: ScreenContext) throws {
        viewModel.onEnter()
        visuals.loadBackground(named: viewModel.imageName, context: context)
        if let musicName = viewModel.musicName {
            visuals.playMusic(named: musicName, context: context)
        }
    }

    func onExit() {
        viewModel.onExit()
        visuals.unloadBackground()
        visuals.stopMusic()
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
    }
}
