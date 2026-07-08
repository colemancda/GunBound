import GunBound

/// View for the publisher splash screens (states 5/6) — all logic/timing
/// lives in `LogoViewModel`; this just loads/draws the named resources it
/// exposes and forwards input.
@MainActor
public final class LogoScreen: GameScreen {
    private let viewModel: LogoViewModel
    private var backgroundTexture: ClientTexture?
    private var audio: ClientAudioPlayer?

    public init(viewModel: LogoViewModel) {
        self.viewModel = viewModel
    }

    public func onEnter(context: ClientContext) throws {
        viewModel.onEnter()
        backgroundTexture = context.renderer.texture(named: viewModel.imageName, assets: context.assets)
        if let musicName = viewModel.musicName {
            let audio = context.makeAudioPlayer()
            audio.play(named: musicName, assets: context.assets, loop: false)
            self.audio = audio
        }
    }

    public func onExit() {
        viewModel.onExit()
        backgroundTexture = nil
        audio?.stop()
        audio = nil
    }

    public func handleInput(_ event: ScreenInputEvent) {
        viewModel.handle(event)
    }

    public func update(deltaTime: Double) {
        audio?.update(deltaTime: deltaTime)
        viewModel.update(deltaTime: deltaTime)
    }

    public func render(_ renderer: ClientRenderer) throws {
        renderer.clear()
        drawFullSize(backgroundTexture, using: renderer)
    }
}
