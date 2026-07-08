import SDL3Swift
import GunBound

/// State 1 — Title screen (`titlemode.img`, `title.mp3`). Any click or
/// keypress advances to Server/Channel Select, matching the original's
/// title-screen "press any key" convention.
@MainActor
final class TitleScreen: ImageBackgroundScreen {
    init() {
        super.init(backgroundImageName: "titlemode.img", musicName: "title.mp3")
    }

    override func handleEvent(_ event: SDLEvent, context: ScreenContext) {
        switch event {
        case .mouseButtonDown, .keyDown:
            context.requestTransition(to: .serverSelect)
        default:
            break
        }
    }
}
