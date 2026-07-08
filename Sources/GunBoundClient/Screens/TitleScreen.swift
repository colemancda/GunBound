import GunBound

/// View for the Title screen (state 1) — all logic lives in
/// `TitleViewModel`; this loads/draws `titlemode.img`/`title.mp3` and
/// reports music-playback state upward each frame (audio polling is
/// backend-specific, so the view model can't do it itself).
@MainActor
public final class TitleScreen: GameScreen {
    private let viewModel: TitleViewModel
    private var backgroundTexture: ClientTexture?
    private var audio: ClientAudioPlayer?

    public init(viewModel: TitleViewModel) {
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
        viewModel.musicPlaybackChanged(isPlaying: audio?.isPlaying ?? false)
        viewModel.update(deltaTime: deltaTime)
    }

    public func render(_ renderer: ClientRenderer) throws {
        renderer.clear()
        drawFullSize(backgroundTexture, using: renderer)
    }
}
