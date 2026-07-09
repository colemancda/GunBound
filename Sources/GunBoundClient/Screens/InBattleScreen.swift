import Foundation
import GunBound
import GunBoundProtocol

/// View for the In-Battle screen (state 11) — the playable slice: the stage
/// terrain through the camera, mobiles grounded on the `.lnd` surface, and
/// the fire loop's visuals — an aim-arc of dots, the power gauge, the
/// projectile, and an **additively-blended** explosion flash (the glow blend
/// the original's scene composer flips to for effect layers). HUD shows the
/// turn, angle, and power.
///
/// Later slices: the layered scene composer (scenery/background, mobile
/// animation frames), terrain destruction, wind, and battle chat.
@MainActor
public final class InBattleScreen: GameScreen {
    private let viewModel: InBattleViewModel
    private var terrainTexture: ClientTexture?
    /// Idle sprites keyed by mobile (one `tankN.img` sheet frame 0 per
    /// distinct mobile in the match).
    private var mobileTextures: [Mobile: ClientTexture] = [:]
    /// A small round dot (`load_back.img` frame 2) reused for the aim arc,
    /// the projectile, and (scaled, additive) the explosion flash.
    private var dotTexture: ClientTexture?
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

        // The stage's collision mask grounds each mobile at its spawn column.
        if let mask = try? assets.terrainMask(named: viewModel.map.stageLandName) {
            viewModel.setTerrain(mask)
        }

        for mobile in Set(viewModel.players.map(\.mobile)) {
            mobileTextures[mobile] = renderer.texture(named: mobile.tankImageName, assets: assets)
        }
        dotTexture = renderer.texture(named: "load_back.img", frame: 2, assets: assets)
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
        dotTexture = nil
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

        // Aim arc: a dotted preview of the shot's opening trajectory while
        // aiming/charging (the physics constants match the simulation).
        if let dotTexture,
           viewModel.isMyTurn,
           viewModel.phase == .aiming || viewModel.phase == .charging,
           let shooter = viewModel.currentTurnPlayer {
            let radians = viewModel.aimAngle * .pi / 180
            let speed = max(0.35, viewModel.power) * InBattleViewModel.maxShotSpeed
            let direction = viewModel.fireDirection
            var x = shooter.x
            var y = shooter.y - 24
            var vx = cos(radians) * speed * direction
            var vy = -sin(radians) * speed
            _ = vx
            for step in 0..<10 {
                let t: Float = 0.06
                vy += InBattleViewModel.gravity * t
                x += cos(radians) * speed * direction * t
                y += vy * t
                let position = viewModel.screenPosition(x: x, y: y)
                let alphaFade = UInt8(200 - step * 15)
                renderer.draw(dotTexture, in: Rect(x: position.x - 3, y: position.y - 3, width: 6, height: 6), tint: (alphaFade, alphaFade, 120))
            }
        }

        // The projectile.
        if let dotTexture, let shot = viewModel.projectile {
            let position = viewModel.screenPosition(x: shot.x, y: shot.y)
            renderer.draw(dotTexture, in: Rect(x: position.x - 5, y: position.y - 5, width: 10, height: 10), tint: (255, 240, 180))
        }

        // The explosion flash — the additive glow blend, expanding and
        // cooling over its lifetime.
        if let dotTexture, let explosion = viewModel.explosion {
            let progress = Float(min(1, explosion.age / InBattleViewModel.explosionDuration))
            let radius = 14 + progress * InBattleViewModel.splashRadius
            let position = viewModel.screenPosition(x: explosion.x, y: explosion.y)
            let heat = UInt8(255 - progress * 140)
            renderer.draw(
                dotTexture,
                in: Rect(x: position.x - radius, y: position.y - radius, width: radius * 2, height: radius * 2),
                tint: (255, heat, UInt8(60 + progress * 40)),
                blend: .additive
            )
        }

        // HUD: map, whose turn, and the aim/power readout.
        font.draw("\(viewModel.map)", x: 12, y: 8, using: renderer)
        if let turn = viewModel.currentTurnPlayer {
            let marker = viewModel.isMyTurn ? "YOUR TURN" : "Turn: \(turn.name)"
            font.draw(marker, x: 12, y: 24, tint: (255, 255, 160), using: renderer)
        }
        if viewModel.isMyTurn, viewModel.phase == .aiming || viewModel.phase == .charging {
            font.draw("Angle \(Int(viewModel.aimAngle))", x: 12, y: 40, using: renderer)
            if viewModel.phase == .charging {
                font.draw("Power \(Int(viewModel.power * 100))", x: 12, y: 56, tint: (255, 180, 120), using: renderer)
            }
        }

        // The power gauge along the bottom while charging.
        if let dotTexture, viewModel.phase == .charging {
            let width = 300 * viewModel.power
            renderer.draw(dotTexture, in: Rect(x: 250, y: 574, width: width, height: 12), tint: (255, UInt8(220 - viewModel.power * 160), 80))
        }
    }
}
