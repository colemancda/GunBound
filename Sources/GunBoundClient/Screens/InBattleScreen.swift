import CSDL3
import SDL3Swift
import GunBound

/// View for the minimal In-Battle stand-in (state 11) — `InBattleViewModel`
/// just identifies the stage terrain sprite; this loads it and scales it to
/// fit the window (it's much larger than the 800x600 logical canvas).
@MainActor
final class InBattleScreen: GameScreen {
    private let viewModel: InBattleViewModel
    private let visuals = ScreenRenderHelper()

    init(viewModel: InBattleViewModel) {
        self.viewModel = viewModel
    }

    func onEnter(context: ScreenContext) throws {
        viewModel.onEnter()
        visuals.loadBackground(named: viewModel.backgroundImageName, context: context)
    }

    func onExit() {
        viewModel.onExit()
        visuals.unloadBackground()
    }

    func handleEvent(_ event: SDLEvent, context: ScreenContext) {
        guard let input = translate(event) else { return }
        viewModel.handle(input)
    }

    func update(deltaTime: Double, context: ScreenContext) {
        viewModel.update(deltaTime: deltaTime)
    }

    func render(_ renderer: SDLRenderer) throws {
        try renderer.setDrawColor(red: 0, green: 0, blue: 0)
        try renderer.clear()
        guard let backgroundTexture = visuals.backgroundTexture else { return }
        let (width, height) = size(of: backgroundTexture)
        guard width > 0, height > 0 else { return }
        let scale = min(800 / width, 600 / height)
        let scaledWidth = width * scale
        let scaledHeight = height * scale
        let destination = SDL_FRect(x: (800 - scaledWidth) / 2, y: (600 - scaledHeight) / 2, w: scaledWidth, h: scaledHeight)
        try renderer.copy(backgroundTexture, destination: destination)
    }
}
