import SDL3Swift
import GunBound

/// State 1 — Title screen (`titlemode.img`, `title.mp3`). Advances to
/// Server/Channel Select once `title.mp3` finishes playing; a click or
/// keypress also skips ahead immediately, matching the original's
/// title-screen "press any key" convention.
@MainActor
final class TitleScreen: ImageBackgroundScreen {
    /// Guards against checking `isMusicPlaying` before playback has actually
    /// started (it's `false` both before the track starts and after it
    /// finishes) — set once the track is confirmed playing.
    private var hasConfirmedPlaying = false

    init() {
        super.init(backgroundImageName: "titlemode.img", musicName: "title.mp3")
    }

    override func onEnter(context: ScreenContext) throws {
        hasConfirmedPlaying = false
        try super.onEnter(context: context)
    }

    override func handleEvent(_ event: SDLEvent, context: ScreenContext) {
        switch event {
        case .mouseButtonDown, .keyDown:
            context.requestTransition(to: .serverSelect)
        default:
            break
        }
    }

    override func update(deltaTime: Double, context: ScreenContext) {
        guard didStartMusic else { return }
        if isMusicPlaying {
            hasConfirmedPlaying = true
        } else if hasConfirmedPlaying {
            context.requestTransition(to: .serverSelect)
        }
    }
}
