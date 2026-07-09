import GunBound
import GunBoundProtocol

/// View for the In-Battle screen (state 11), slice 1 — the static scene:
/// the stage terrain (the map codename's `.img`, frame 0) drawn through the
/// camera at world scale, each combatant's mobile (their `tankN.img` sheet,
/// frame 0 = idle) at its spawn position with a team-colored name tag, and a
/// minimal HUD (map name + whose turn). The camera pans with the original's
/// screen-edge scroll (view-model logic).
///
/// Later slices: the layered scene composer (background atlas, effects with
/// additive blend, mobile animation frames), the terrain mask (`.lnd`),
/// aiming/firing, and battle chat.
@MainActor
public final class InBattleScreen: GameScreen {
    private let viewModel: InBattleViewModel
    private var terrainTexture: ClientTexture?
    /// Idle sprites keyed by mobile (one `tankN.img` frame 0 per distinct
    /// mobile in the match).
    private var mobileTextures: [Mobile: ClientTexture] = [:]
    private var font: LoadedFont?
    private var audio: ClientAudioPlayer?

    public init(viewModel: InBattleViewModel) {
        self.viewModel = viewModel
    }

    public func onEnter(context: ClientContext) throws {
        viewModel.onEnter()
        let renderer = context.renderer
        let assets = context.assets

        terrainTexture = renderer.texture(named: viewModel.map.stageImageName, assets: assets)
        let (worldWidth, worldHeight) = renderer.size(of: terrainTexture)
        viewModel.setWorldSize(width: worldWidth, height: worldHeight)

        for mobile in Set(viewModel.players.map(\.mobile)) {
            mobileTextures[mobile] = renderer.texture(named: mobile.tankImageName, assets: assets)
        }
        font = LoadedFont(.latinFont, renderer: renderer, assets: assets)

        // Battle music: `stage%d.mp3` by stage id, or one of the six tracks
        // at random for the random stage — the decompiled `PlayMusicTrack`
        // behaviour (`stage id or rand()%6 + 1`).
        let stageID = Int(viewModel.map.rawValue)
        let track = stageID > 0 ? stageID : Int.random(in: 1...6)
        let audio = context.makeAudioPlayer()
        audio.play(named: "stage\(track).mp3", assets: assets, loop: true)
        self.audio = audio
    }

    public func onExit() {
        viewModel.onExit()
        terrainTexture = nil
        mobileTextures = [:]
        font = nil
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

        // The stage world, offset by the camera (world → screen is
        // `world − cam + halfView`; drawing the full map at the transformed
        // origin is equivalent).
        if let terrainTexture {
            let (width, height) = renderer.size(of: terrainTexture)
            let origin = viewModel.screenPosition(x: 0, y: 0)
            renderer.draw(terrainTexture, in: Rect(x: origin.x, y: origin.y, width: width, height: height), tint: nil)
        }

        guard let font else { return }

        // Mobiles at their spawns: idle sprite centered on the spawn point,
        // name tag above in team color, dead players grayed.
        for player in viewModel.players {
            let position = viewModel.screenPosition(x: player.x, y: player.y)
            guard position.x > -60, position.x < 860, position.y > -60, position.y < 660 else { continue }
            let teamColor: (r: UInt8, g: UInt8, b: UInt8) = player.team == .a ? (255, 200, 120) : (140, 200, 255)

            if let sprite = mobileTextures[player.mobile] {
                let (width, height) = renderer.size(of: sprite)
                let tint: (r: UInt8, g: UInt8, b: UInt8)? = player.isAlive ? nil : (90, 90, 90)
                renderer.draw(
                    sprite,
                    in: Rect(x: position.x - width / 2, y: position.y - height, width: width, height: height),
                    tint: tint
                )
            }
            let tagWidth = font.width(of: player.name)
            font.draw(
                player.name,
                x: position.x - tagWidth / 2,
                y: position.y - 58,
                tint: player.isAlive ? teamColor : (110, 110, 110),
                using: renderer
            )
        }

        // Minimal HUD: map name and whose turn (display-only for now).
        font.draw("\(viewModel.map)", x: 12, y: 8, using: renderer)
        if let turn = viewModel.currentTurnPlayer {
            font.draw("Turn: \(turn.name)", x: 12, y: 24, tint: (255, 255, 160), using: renderer)
        }
    }
}
