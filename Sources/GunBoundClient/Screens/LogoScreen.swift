import SDL3Swift
import GunBound

/// Publisher splash screen (states 5/6 in the decomp's `CGameState` table) —
/// loads a full-window logo image + jingle, and auto-advances after a fixed
/// duration (matching `ARCHITECTURE.md`'s "~2 second, non-interactive
/// publisher splash" note), or immediately on any click/keypress.
@MainActor
final class LogoScreen: ImageBackgroundScreen {
    private let nextMode: ClientMode
    private let duration: Double
    private var elapsed: Double = 0

    init(imageName: String, musicName: String?, duration: Double = 2.5, next: ClientMode) {
        self.nextMode = next
        self.duration = duration
        super.init(backgroundImageName: imageName, musicName: musicName)
    }

    override func onEnter(context: ScreenContext) throws {
        elapsed = 0
        try super.onEnter(context: context)
    }

    override func handleEvent(_ event: SDLEvent, context: ScreenContext) {
        switch event {
        case .mouseButtonDown, .keyDown:
            context.requestTransition(to: nextMode)
        default:
            break
        }
    }

    override func update(deltaTime: Double, context: ScreenContext) {
        elapsed += deltaTime
        if elapsed >= duration {
            context.requestTransition(to: nextMode)
        }
    }
}
