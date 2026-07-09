import GunBound

/// View for the minimal In-Battle stand-in (state 11) — `InBattleViewModel`
/// just identifies the stage terrain sprite; this loads it and scales it to
/// fit the window (it's much larger than the 800x600 logical canvas).
@MainActor
public final class InBattleScreen: GameScreen {
    private let viewModel: InBattleViewModel
    private var backgroundTexture: ClientTexture?

    public init(viewModel: InBattleViewModel) {
        self.viewModel = viewModel
    }

    public func onEnter(context: ClientContext) throws {
        viewModel.onEnter()
        backgroundTexture = context.renderer.texture(named: viewModel.backgroundImageName, assets: context.assets)
    }

    public func onExit() {
        viewModel.onExit()
        backgroundTexture = nil
    }

    public func handleInput(_ event: ScreenInputEvent) {
        viewModel.handle(event)
    }

    public func update(deltaTime: Double) {
        viewModel.update(deltaTime: deltaTime)
    }

    public func render(_ renderer: ClientRenderer) throws {
        renderer.clear()
        guard let backgroundTexture else { return }
        let (width, height) = renderer.size(of: backgroundTexture)
        guard width > 0, height > 0 else { return }
        let scale = min(800 / width, 600 / height)
        let scaledWidth = width * scale
        let scaledHeight = height * scale
        let rect = Rect(x: (800 - scaledWidth) / 2, y: (600 - scaledHeight) / 2, width: scaledWidth, height: scaledHeight)
        renderer.draw(backgroundTexture, in: rect, tint: nil)
    }
}
