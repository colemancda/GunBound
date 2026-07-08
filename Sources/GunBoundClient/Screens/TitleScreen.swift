import SDL3Swift
import GunBound

/// View for the Title screen (state 1) — all logic lives in
/// `TitleViewModel`; this loads/draws `titlemode.img`/`title.mp3` and
/// reports music-playback state upward each frame (audio polling is
/// SDL-specific, so the view model can't do it itself).
@MainActor
final class TitleScreen: GameScreen {
    private let viewModel: TitleViewModel
    private let visuals = ScreenRenderHelper()

    init(viewModel: TitleViewModel) {
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
        viewModel.musicPlaybackChanged(isPlaying: visuals.isMusicPlaying)
        viewModel.update(deltaTime: deltaTime)
    }

    func render(_ renderer: SDLRenderer) throws {
        try visuals.clearAndDrawBackground(renderer)
    }
}
