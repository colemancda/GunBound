import CSDL3
import SDL3Swift
import GunBound

/// State 11 — In-Battle. The real client's render pipeline here is a full
/// Direct3D7 + software-blit hybrid driving tanks, turns, weapons, and
/// networked player state (see `ARCHITECTURE.md`'s rendering section) — all
/// of that is out of scope for this pass. This is a minimal stand-in that
/// proves out terrain-asset rendering only: it draws the selected stage's
/// full terrain image (e.g. `cave.img`, a real 1800x1800 destructible-
/// terrain sprite), scaled to fit the window, with no tanks/physics/turns/
/// networking. Any click returns to the Game Room List.
@MainActor
final class InBattleScreen: ImageBackgroundScreen {
    /// Real stage terrain sprites confirmed to exist and be full
    /// stage-sized (1800x1800) in `graphics.xfs` — not derived from
    /// `stage.dat`, since the stage-name-to-terrain-image mapping isn't
    /// reverse-engineered yet (see `FILEFORMATS.md`).
    static let stageImageName = "cave.img"

    init() {
        super.init(backgroundImageName: InBattleScreen.stageImageName, musicName: nil)
    }

    override func handleEvent(_ event: SDLEvent, context: ScreenContext) {
        switch event {
        case .mouseButtonDown, .keyDown:
            context.requestTransition(to: .gameRoomList)
        default:
            break
        }
    }

    override func render(_ renderer: SDLRenderer) throws {
        try renderer.setDrawColor(red: 0, green: 0, blue: 0)
        try renderer.clear()
        guard let backgroundTexture else { return }
        let attributes = try backgroundTexture.attributes()
        // The terrain sprite (1800x1800) is much larger than the window's
        // 800x600 logical canvas — scale it down uniformly to fit rather
        // than drawing at native size (which would only show a tiny corner).
        let scale = min(800.0 / Float(attributes.width), 600.0 / Float(attributes.height))
        let width = Float(attributes.width) * scale
        let height = Float(attributes.height) * scale
        let destination = SDL_FRect(x: (800 - width) / 2, y: (600 - height) / 2, w: width, h: height)
        try renderer.copy(backgroundTexture, destination: destination)
    }
}
