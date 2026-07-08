import CSDL3
import SDL3Swift
import GunBound

/// State 10 — Loading (`load_back.img`, `load_stage00.img`). Real client shows
/// per-player ready icons here; this pass just shows the loading chrome for
/// a fixed short duration before advancing to the (also minimal) In-Battle
/// level render — there's no session/player-ready logic to wait on since
/// there's no networking yet.
@MainActor
final class LoadingScreen: ImageBackgroundScreen {
    private var stageOverlay: SDLTexture?
    private var elapsed: Double = 0
    private let duration: Double = 1.2

    init() {
        super.init(backgroundImageName: "load_back.img", musicName: nil)
    }

    override func onEnter(context: ScreenContext) throws {
        elapsed = 0
        try super.onEnter(context: context)
        stageOverlay = loadTexture(named: "load_stage00.img", context: context)
    }

    override func onExit() {
        stageOverlay = nil
        super.onExit()
    }

    override func update(deltaTime: Double, context: ScreenContext) {
        elapsed += deltaTime
        if elapsed >= duration {
            context.requestTransition(to: .inGameSession)
        }
    }

    override func render(_ renderer: SDLRenderer) throws {
        try super.render(renderer)
        if let stageOverlay {
            let attributes = try stageOverlay.attributes()
            try renderer.copy(stageOverlay, destination: SDL_FRect(x: 0, y: 0, w: Float(attributes.width), h: Float(attributes.height)))
        }
    }
}
